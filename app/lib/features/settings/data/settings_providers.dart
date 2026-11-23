import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/settings_repository.dart';

/// Overridden by the composition root with the demo or live implementation.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw StateError('Settings repository initialization required'),
);
