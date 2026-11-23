import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/water_repository.dart';

/// Overridden by the composition root with the demo or live implementation.
final waterRepositoryProvider = Provider<WaterRepository>(
  (ref) => throw StateError('Water repository initialization required'),
);
