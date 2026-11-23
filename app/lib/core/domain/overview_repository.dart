import 'overview.dart';

/// Reads the person's profile, meals, targets and water as one snapshot.
/// Several features read it, so it lives with the shared entities.
abstract interface class OverviewRepository {
  Future<Overview> overview();
}
