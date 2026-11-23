import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/today_repository.dart';

/// Overridden by the composition root with the demo or live implementation.
final todayRepositoryProvider = Provider<TodayRepository>(
  (ref) => throw StateError('Today repository initialization required'),
);
