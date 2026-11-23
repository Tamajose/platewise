import '../../../core/data/api/api_client.dart';
import '../../../core/data/demo/demo_store.dart';
import '../../../core/domain/domain.dart';
import '../domain/energy.dart';
import '../domain/settings_repository.dart';
import '../domain/settings_rules.dart';

class LiveSettingsRepository implements SettingsRepository {
  LiveSettingsRepository(this._api, {required this.signOutLocally});

  final ApiClient _api;

  /// Ends the session on this device. A deleted account cannot sign in again,
  /// so this runs after account deletion.
  final Future<void> Function() signOutLocally;

  @override
  Future<void> setCorrectionConsent(bool enabled) async {
    await _api.call('correction_consent', {'enabled': enabled});
  }

  @override
  Future<void> submitCorrection(String id, Correction correction) async {
    await _api.call('share_correction', {
      'id': id,
      'food_key': correction.food,
      'grams': correction.grams,
      'calorie_low': correction.range.low,
      'calorie_high': correction.range.high,
    });
  }

  @override
  Future<EnergyEstimate> estimateEnergy(
    Profile profile,
    int age,
    String coefficient,
    String activity,
  ) async {
    final result = await _api.call('estimate_energy', {
      'age': age,
      'coefficient': coefficient,
      'activity': activity,
      'eligible': true,
    });
    return (
      resting: result['resting_kcal'] as int,
      total: result['total_kcal'] as int,
      multiplier: (result['activity_factor'] as num).toDouble(),
      canApply: result['can_apply'] == true,
    );
  }

  @override
  Future<void> eraseData({required bool account}) async {
    await _api.call(account ? 'delete_account' : 'delete_data');
    if (account) {
      try {
        await signOutLocally();
      } on Object {
        /* A deleted account cannot authenticate on the next request. */
      }
    }
  }
}

class DemoSettingsRepository implements SettingsRepository {
  DemoSettingsRepository(this._store);

  final DemoStore _store;

  @override
  Future<void> setCorrectionConsent(bool enabled) => _store.update((state) {
    final profile = state.profile;
    if (profile == null) throw const Failure('Set up a profile first.');
    return state.copyWith(
      profile: profile.copyWith(correctionConsent: enabled),
    );
  });

  @override
  Future<void> submitCorrection(String id, Correction correction) async {
    throw const Failure(
      'This demo keeps data on your device. Shared corrections require a live account session.',
    );
  }

  @override
  Future<EnergyEstimate> estimateEnergy(
    Profile profile,
    int age,
    String coefficient,
    String activity,
  ) async {
    if (parseEnergyAge('$age') == null) {
      throw const Failure('The pilot formula supports ages 19 to 78.');
    }
    return calculateEnergy(profile, age, coefficient, activity);
  }

  @override
  Future<void> eraseData({required bool account}) =>
      _store.update((_) => const Overview());
}
