import 'package:material_ui/material_ui.dart';

import '../core/theme/plate_theme.dart';
import '../core/widgets/widgets.dart';

/// Shown instead of the app when it cannot start.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'PlateWise',
    theme: plateTheme(),
    home: Standalone(
      title: 'PlateWise',
      body: PageScroll(children: [ErrorState(message)]),
    ),
  );
}
