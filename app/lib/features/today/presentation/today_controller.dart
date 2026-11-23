import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/session_state.dart';
import '../data/today_providers.dart';

/// Actions on the daily log. Each one refreshes the overview afterwards, so
/// the screen shows what the service now holds even when the action failed.
class TodayActions {
  TodayActions(this._ref);

  final Ref _ref;

  /// Deletes a meal. Returns null on success, or the message to show.
  Future<String?> deleteMeal(String id) async {
    try {
      await _ref.read(todayRepositoryProvider).deleteMeal(id);
      return null;
    } on Object catch (e) {
      return failureMessage(e);
    } finally {
      _ref.invalidate(overviewProvider);
    }
  }

  /// Asks the service to finish deleting photos left behind. Returns null on
  /// success, or the message to show.
  Future<String?> retryPhotoCleanup() async {
    try {
      await _ref.read(mediaStorageProvider).retryCleanup();
      return null;
    } on Object catch (e) {
      return failureMessage(e);
    } finally {
      _ref.invalidate(overviewProvider);
    }
  }
}

final todayActionsProvider = Provider<TodayActions>(TodayActions.new);
