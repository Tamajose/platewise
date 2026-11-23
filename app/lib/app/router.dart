import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/presentation/review_args.dart';
import '../core/presentation/routes.dart';
import '../features/comparison/presentation/decide_screen.dart';
import '../features/comparison/presentation/menu_review_args.dart';
import '../features/comparison/presentation/menu_review_screen.dart';
import '../features/meal_logging/presentation/capture_screen.dart';
import '../features/meal_logging/presentation/review_screen.dart';
import '../features/nearby/presentation/nearby_screen.dart';
import '../features/today/presentation/today_screen.dart';
import '../features/water/presentation/water_quick_add.dart';
import '../features/weekly/presentation/progress_screen.dart';
import '../features/water/presentation/water_screen.dart';
import 'gate.dart';
import 'placeholder_screen.dart';
import 'shell.dart';

/// Maps each route path to a screen. Screens navigate by path, so this is the
/// one place that knows which feature shows what.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(path: Routes.home, builder: (_, _) => const AppGate()),
      GoRoute(
        path: Routes.welcome,
        builder: (_, _) => const PlaceholderScreen('Welcome'),
      ),
      ShellRoute(
        builder: (_, state, child) =>
            AppShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: Routes.today,
            builder: (_, _) => TodayScreen(
              waterQuickAdd: (log, goal) =>
                  WaterQuickAdd(log, goal, compact: true),
            ),
          ),
          GoRoute(path: Routes.decide, builder: (_, _) => const DecideScreen()),
          GoRoute(path: Routes.nearby, builder: (_, _) => const NearbyScreen()),
          GoRoute(
            path: Routes.progress,
            builder: (_, _) => const ProgressScreen(),
          ),
        ],
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
        redirect: (_, state) => state.extra is ReviewArgs ? null : Routes.today,
        builder: (_, state) => ReviewScreen(state.extra! as ReviewArgs),
      ),
      GoRoute(path: Routes.water, builder: (_, _) => const WaterScreen()),
      GoRoute(
        path: Routes.profile,
        builder: (_, _) => const PlaceholderScreen('Profile'),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, _) => const PlaceholderScreen('Settings'),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
