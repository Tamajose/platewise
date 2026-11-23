import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/overview_repository.dart';
import '../domain/session_repository.dart';

/// Overridden by the composition root with the demo or live implementation.
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => throw StateError('Session repository initialization required'),
);

/// Overridden by the composition root with the demo or live implementation.
final overviewRepositoryProvider = Provider<OverviewRepository>(
  (ref) => throw StateError('Overview repository initialization required'),
);
