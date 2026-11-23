import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/account_info.dart';
import '../domain/account_repository.dart';

/// Overridden by the composition root with the demo or live implementation.
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => throw StateError('Account repository initialization required'),
);

/// The current account, read from the service.
final accountProvider = FutureProvider.autoDispose<AccountInfo>(
  (ref) => ref.watch(accountRepositoryProvider).account(),
);
