import '../../../core/domain/profile.dart';

abstract interface class ProfileRepository {
  /// Saves the profile. [targetConfirmed] says the person confirmed that
  /// adult target-setting applies to them, which a target requires. Throws a
  /// `Failure` when the target is outside the pilot range or unconfirmed.
  Future<void> save(Profile profile, {required bool targetConfirmed});
}
