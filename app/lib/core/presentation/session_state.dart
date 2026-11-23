import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/core_providers.dart';
import '../domain/domain.dart';

/// The person's current snapshot. Features that change data invalidate this.
final overviewProvider = FutureProvider<Overview>((ref) async {
  await ref.watch(sessionRepositoryProvider).bootstrap();
  return ref.watch(overviewRepositoryProvider).overview();
});

final capabilitiesProvider = FutureProvider<Capabilities>((ref) async {
  final session = ref.watch(sessionRepositoryProvider);
  await session.bootstrap();
  return session.capabilities();
});
