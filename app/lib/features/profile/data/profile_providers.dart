import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/profile_repository.dart';

/// Overridden by the composition root with the demo or live implementation.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => throw StateError('Profile repository initialization required'),
);
