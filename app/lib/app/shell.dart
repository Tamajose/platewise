import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/data/core_providers.dart';
import '../core/presentation/routes.dart';
import '../core/theme/plate_theme.dart';
import '../core/widgets/widgets.dart';

const _destinations = [
  (
    path: Routes.today,
    label: 'Today',
    icon: Icons.today_outlined,
    selected: Icons.today_rounded,
  ),
  (
    path: Routes.decide,
    label: 'Decide',
    icon: Icons.compare_arrows_rounded,
    selected: Icons.compare_arrows_rounded,
  ),
  (
    path: Routes.nearby,
    label: 'Nearby',
    icon: Icons.place_outlined,
    selected: Icons.place_rounded,
  ),
  (
    path: Routes.progress,
    label: 'Progress',
    icon: Icons.insights_outlined,
    selected: Icons.insights,
  ),
];

/// The frame around the four main screens: a bottom bar on narrow screens and
/// a side rail on wide ones.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.path, required this.child});

  /// The current route, which picks the highlighted destination.
  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(sessionRepositoryProvider).isDemo;
    final wide =
        MediaQuery.sizeOf(context).width >= 1000 &&
        MediaQuery.textScalerOf(context).scale(14) <= 20;
    final selected = _destinations
        .indexWhere((item) => item.path == path)
        .clamp(0, _destinations.length - 1);
    void go(int index) => context.go(_destinations[index].path);

    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: const Wordmark(),
              actions: [
                if (demo) const Center(child: IndicatorTag('Demo mode')),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: IconButton(
                    onPressed: () => context.push(Routes.settings),
                    tooltip: 'Settings and profile',
                    icon: const Icon(Icons.account_circle_outlined),
                  ),
                ),
              ],
            ),
      body: Row(
        children: [
          if (wide) ...[
            SafeArea(
              right: false,
              child: NavigationRail(
                extended: true,
                minExtendedWidth: 192,
                scrollable: true,
                backgroundColor: PlateColors.surface,
                indicatorColor: PlateColors.sage,
                leading: const Padding(
                  padding: EdgeInsets.fromLTRB(18, 14, 18, 24),
                  child: SizedBox(width: 156, child: Wordmark()),
                ),
                trailingAtBottom: true,
                trailing: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                  child: Column(
                    children: [
                      if (demo) const IndicatorTag('Demo mode'),
                      TextButton.icon(
                        onPressed: () => context.push(Routes.settings),
                        icon: const Icon(Icons.account_circle_outlined),
                        label: const Text('Settings'),
                      ),
                    ],
                  ),
                ),
                selectedIndex: selected,
                onDestinationSelected: go,
                destinations: [
                  for (final item in _destinations)
                    NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selected),
                      label: Text(item.label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(key: const ValueKey('active-screen'), child: child),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: PlateColors.line)),
              ),
              child: NavigationBar(
                selectedIndex: selected,
                onDestinationSelected: go,
                destinations: [
                  for (final item in _destinations)
                    NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selected),
                      label: item.label,
                    ),
                ],
              ),
            ),
    );
  }
}
