import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/presentation/review_args.dart';
import '../core/presentation/routes.dart';
import '../features/comparison/presentation/decide_screen.dart';
import '../features/comparison/presentation/menu_review_args.dart';
import '../features/comparison/presentation/menu_review_screen.dart';
import '../features/meal_logging/presentation/capture_screen.dart';
import '../features/meal_logging/presentation/review_screen.dart';

/// Maps each route path to a screen. Screens navigate by path, so this is the
/// one place that knows which feature shows what.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(path: Routes.home, builder: (_, _) => const _TemporaryHome()),
      GoRoute(path: Routes.today, builder: (_, _) => const _TemporaryHome()),
      GoRoute(
        path: Routes.decide,
        builder: (_, _) => Scaffold(
          appBar: AppBar(title: const Text('Decide')),
          body: const DecideScreen(),
        ),
      ),
      GoRoute(
        path: Routes.menuReview,
        redirect: (_, state) =>
            state.extra is MenuReviewArgs ? null : Routes.decide,
        builder: (_, state) => MenuReviewScreen(state.extra! as MenuReviewArgs),
      ),
      GoRoute(path: Routes.log, builder: (_, _) => const CaptureScreen()),
      GoRoute(
        path: Routes.review,
        redirect: (_, state) => state.extra is ReviewArgs ? null : Routes.home,
        builder: (_, state) => ReviewScreen(state.extra! as ReviewArgs),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Stands in for the real start screen until the daily log and onboarding
/// arrive, so meal logging can be tried in the running app.
class _TemporaryHome extends StatelessWidget {
  const _TemporaryHome();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('PlateWise'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => context.push(Routes.log),
            child: const Text('Log a meal'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.push(Routes.decide),
            child: const Text('Decide'),
          ),
        ],
      ),
    ),
  );
}
