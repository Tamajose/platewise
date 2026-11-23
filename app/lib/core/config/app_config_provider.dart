import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

/// Build-time configuration. The composition root overrides this with the
/// configuration the app started with.
final configProvider = Provider((ref) => const AppConfig());
