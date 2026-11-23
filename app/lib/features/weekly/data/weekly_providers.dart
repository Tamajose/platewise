import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/weekly_repository.dart';

/// Overridden by the composition root with the demo or live implementation.
final weeklyRepositoryProvider = Provider<WeeklyRepository>(
  (ref) => throw StateError('Weekly repository initialization required'),
);
