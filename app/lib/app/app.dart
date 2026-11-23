import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/plate_theme.dart';
import 'router.dart';

/// The application shell: theme and routing. Features are added to the router
/// by later migration steps.
class PlateWiseApp extends ConsumerWidget {
  const PlateWiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'PlateWise',
    debugShowCheckedModeBanner: false,
    theme: plateTheme(),
    routerConfig: ref.watch(routerProvider),
  );
}
