import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/comparison_repository.dart';

/// Overridden by the composition root with the demo or live implementation.
final comparisonRepositoryProvider = Provider<ComparisonRepository>(
  (ref) => throw StateError('Comparison repository initialization required'),
);
