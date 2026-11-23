import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

/// Composition root. Later steps select the demo or live repositories here and
/// pass them to the feature providers through [ProviderScope] overrides.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: PlateWiseApp()));
}
