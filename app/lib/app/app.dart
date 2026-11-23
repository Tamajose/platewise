import 'package:material_ui/material_ui.dart';

import '../core/theme/plate_theme.dart';

/// Placeholder application shell. The router and feature screens are added by
/// later migration steps.
class PlateWiseApp extends StatelessWidget {
  const PlateWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlateWise',
      theme: plateTheme(),
      home: const Scaffold(body: Center(child: Text('PlateWise'))),
    );
  }
}
