import '../../../core/domain/profile.dart';
import 'energy.dart';
import 'stats_export.dart';

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

  /// The statistics for the last [days] days, or fewer when older days hold
  /// no records. [days] is 7 to 365.
  Future<StatsExport> exportStats(int days);

  /// Deletes the person's data, and their account when [account] is true.
  Future<void> eraseData({required bool account});
}
