import '../../../core/domain/profile.dart';
import 'energy.dart';

abstract interface class SettingsRepository {
  /// Turns correction contributions on or off. Turning them off removes the
  /// queued ones.
  Future<void> setCorrectionConsent(bool enabled);

  /// Submits a food correction for review. [id] makes a retry safe.
  Future<void> submitCorrection(String id, Correction correction);

  /// Mifflin–St Jeor estimate for [profile]. Throws a `Failure` for an age the
  /// pilot formula does not cover.
  Future<EnergyEstimate> estimateEnergy(
    Profile profile,
    int age,
    String coefficient,
    String activity,
  );

  /// Deletes the person's data, and their account when [account] is true.
  Future<void> eraseData({required bool account});
}
