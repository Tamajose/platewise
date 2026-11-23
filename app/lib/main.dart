import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as timezone;

import 'app/app.dart';
import 'app/composition.dart';
import 'app/startup_error_app.dart';
import 'core/config/app_config.dart';

/// Composition root. [composeOverrides] chooses the demo or live
/// implementations, and this file only starts the app with them.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  timezone.initializeTimeZones();
  try {
    final overrides = await composeOverrides(const AppConfig());
    runApp(ProviderScope(overrides: overrides, child: const PlateWiseApp()));
  } on StartupException catch (error) {
    runApp(StartupErrorApp(error.message));
  }
}
