import 'package:material_ui/material_ui.dart';

/// Placeholder application shell. The theme, router and feature screens are
/// added by later migration steps.
class PlateWiseApp extends StatelessWidget {
  const PlateWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'PlateWise',
      home: Scaffold(body: Center(child: Text('PlateWise'))),
    );
  }
}
