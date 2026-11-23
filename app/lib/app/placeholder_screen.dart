import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/presentation/routes.dart';
import '../core/widgets/widgets.dart';

/// Stands in for a screen that a later migration step adds, so the routes the
/// finished app uses already resolve.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen(this.title, {super.key, this.standalone = true});

  final String title;

  /// Whether to draw its own app bar, instead of sitting inside the shell.
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final body = PageScroll(
      children: [
        PageHeading(title, detail: 'This screen is added in a later step.'),
        const SizedBox(height: 16),
        SecondaryButton(
          'Go to Today',
          icon: Icons.today_outlined,
          onPressed: () => context.go(Routes.today),
        ),
      ],
    );
    return standalone ? Standalone(title: title, body: body) : body;
  }
}
