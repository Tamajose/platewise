import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/domain/domain.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/session_state.dart';
import '../data/settings_providers.dart';
import '../domain/energy.dart';
import '../domain/settings_rules.dart';

class SettingsState {
  const SettingsState({this.busy = false, this.error});
  final bool busy;
  final String? error;
}

/// Privacy and data actions on the settings screen. Each refreshes the
/// overview afterwards, even when it failed, so the screen shows what the
/// service now holds.
class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  Future<bool> setCorrectionConsent(bool enabled) => _work(
    () => ref.read(settingsRepositoryProvider).setCorrectionConsent(enabled),
  );

  Future<bool> retryPhotoCleanup() =>
      _work(() => ref.read(mediaStorageProvider).retryCleanup());

  /// Deletes the person's data, and their account when [account] is true.
  Future<bool> erase({required bool account}) => _work(
    () => ref.read(settingsRepositoryProvider).eraseData(account: account),
  );

  Future<bool> _work(Future<void> Function() action) async {
    state = const SettingsState(busy: true);
    try {
      await action();
      if (ref.mounted) state = const SettingsState();
      return true;
    } on Object catch (e) {
      if (ref.mounted) state = SettingsState(error: failureMessage(e));
      return false;
    } finally {
      if (ref.mounted) ref.invalidate(overviewProvider);
    }
  }
}

final settingsControllerProvider =
    NotifierProvider.autoDispose<SettingsController, SettingsState>(
      SettingsController.new,
    );

class EnergyState {
  const EnergyState({
    this.eligible = false,
    this.age = '',
    this.coefficient,
    this.activity,
    this.result,
    this.busy = false,
    this.error,
  });

  final bool eligible, busy;
  final String age;
  final String? coefficient, activity, error;
  final EnergyEstimate? result;

  EnergyState copyWith({
    bool? eligible,
    String? age,
    String? coefficient,
    String? activity,
    EnergyEstimate? result,
    bool? busy,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) => EnergyState(
    eligible: eligible ?? this.eligible,
    age: age ?? this.age,
    coefficient: coefficient ?? this.coefficient,
    activity: activity ?? this.activity,
    result: clearResult ? null : result ?? this.result,
    busy: busy ?? this.busy,
    error: clearError ? null : error ?? this.error,
  );
}

/// State of the energy estimate screen. Changing any input discards the old
/// result, so a number on screen always matches the inputs shown.
class EnergyController extends Notifier<EnergyState> {
  @override
  EnergyState build() => const EnergyState();

  void setEligible(bool value) =>
      state = state.copyWith(eligible: value, clearResult: true);
  void setAge(String value) =>
      state = state.copyWith(age: value, clearResult: true);
  void setCoefficient(String? value) =>
      state = state.copyWith(coefficient: value, clearResult: true);
  void setActivity(String? value) =>
      state = state.copyWith(activity: value, clearResult: true);

  Future<void> calculate(Profile profile) async {
    final age = parseEnergyAge(state.age);
    if (!state.eligible ||
        age == null ||
        state.coefficient == null ||
        state.activity == null) {
      state = state.copyWith(error: energyInputMessage);
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      final result = await ref
          .read(settingsRepositoryProvider)
          .estimateEnergy(profile, age, state.coefficient!, state.activity!);
      if (ref.mounted) state = state.copyWith(busy: false, result: result);
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(busy: false, error: failureMessage(e));
      }
    }
  }

  /// Saves [total] as the daily target from today. Returns whether it was
  /// saved.
  Future<bool> applyAsTarget(Profile profile, int total) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .save(profile.copyWith(target: total), targetConfirmed: true);
      ref.invalidate(overviewProvider);
      if (ref.mounted) state = state.copyWith(busy: false);
      return true;
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(busy: false, error: failureMessage(e));
      }
      return false;
    }
  }
}

final energyControllerProvider =
    NotifierProvider.autoDispose<EnergyController, EnergyState>(
      EnergyController.new,
    );

/// Submits a food correction. The id is fixed for the life of the screen, so
/// submitting again after a lost reply cannot duplicate it.
class CorrectionController extends Notifier<SettingsState> {
  late final String _id;

  @override
  SettingsState build() {
    _id = ref.read(idGeneratorProvider)();
    return const SettingsState();
  }

  Future<bool> submit(Correction correction) async {
    state = const SettingsState(busy: true);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .submitCorrection(_id, correction);
      if (ref.mounted) state = const SettingsState();
      return true;
    } on Object catch (e) {
      if (ref.mounted) state = SettingsState(error: failureMessage(e));
      return false;
    }
  }

  void fail(String message) => state = SettingsState(error: message);
}

final correctionControllerProvider =
    NotifierProvider.autoDispose<CorrectionController, SettingsState>(
      CorrectionController.new,
    );
