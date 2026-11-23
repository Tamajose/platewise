import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/domain/day_log.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/session_state.dart';
import '../data/water_providers.dart';

class WaterState {
  const WaterState({this.busy = false, this.error, this.failedAmount});

  final bool busy;
  final String? error;

  /// The amount whose last attempt failed, so "Try again" can repeat it.
  final int? failedAmount;
}

/// Adds, changes and removes water entries. It lives as long as the app, so an
/// undo offered in a snack bar still works after leaving the screen.
class WaterController extends Notifier<WaterState> {
  String? _pendingId;
  int? _pendingAmount;

  @override
  WaterState build() => const WaterState();

  /// Adds [amount] ml. Returns the new entry's id, or null when it failed, in
  /// which case [WaterState.error] says why. Trying the same amount again
  /// after a failure reuses the id, so a lost reply cannot count twice.
  Future<String?> add(int amount) async {
    if (state.busy) return null;
    if (_pendingAmount != amount) _pendingId = null;
    final id = _pendingId ??= ref.read(idGeneratorProvider)();
    _pendingAmount = amount;
    state = const WaterState(busy: true);
    try {
      await ref.read(waterRepositoryProvider).save(id, amount);
      _pendingId = null;
      ref.invalidate(overviewProvider);
      state = const WaterState();
      return id;
    } on Object catch (e) {
      state = WaterState(error: failureMessage(e), failedAmount: amount);
      return null;
    }
  }

  /// Changes an entry. Returns null on success, or the message to show.
  Future<String?> edit(WaterEntry entry, int amount) => _run(
    () => ref
        .read(waterRepositoryProvider)
        .save(entry.id, amount, revision: entry.revision),
  );

  /// Removes an entry. Returns null on success, or the message to show.
  Future<String?> remove(String id) =>
      _run(() => ref.read(waterRepositoryProvider).remove(id));

  Future<String?> _run(Future<void> Function() action) async {
    try {
      await action();
      return null;
    } on Object catch (e) {
      return failureMessage(e);
    } finally {
      ref.invalidate(overviewProvider);
    }
  }
}

final waterControllerProvider = NotifierProvider<WaterController, WaterState>(
  WaterController.new,
);
