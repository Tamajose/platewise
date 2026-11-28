import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/data/core_providers.dart';
import '../core/presentation/routes.dart';
import '../core/theme/plate_theme.dart';
import '../core/widgets/widgets.dart';
import '../core/l10n/l10n.dart';

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
/// a side rail on wide ones. The rail folds down to icons.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.path, required this.child});

  /// The current route, which picks the highlighted destination.
  final String path;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool collapsed = false;

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(sessionRepositoryProvider).isDemo;
    final wide =
        MediaQuery.sizeOf(context).width >= 1000 &&
        MediaQuery.textScalerOf(context).scale(14) <= 20;
    final selected = _destinations
        .indexWhere((item) => item.path == widget.path)
        .clamp(0, _destinations.length - 1);
    void go(int index) => context.go(_destinations[index].path);

    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: const Wordmark(),
              actions: [
                const LanguageSwitchButton(),
                if (demo) Center(child: IndicatorTag(context.tr('Demo mode'))),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: IconButton(
                    onPressed: () => context.push(Routes.me),
                    tooltip: context.tr('Profile'),
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
                extended: !collapsed,
                minExtendedWidth: 224,
                minWidth: 76,
                scrollable: true,
                backgroundColor: PlateColors.surface,
                indicatorColor: PlateColors.sage,
                indicatorShape: const StadiumBorder(),
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
                  child: Builder(
                    builder: (context) {
                      final toggle = IconButton(
                        onPressed: () => setState(() => collapsed = !collapsed),
                        tooltip: collapsed
                            ? 'Expand sidebar'
                            : 'Collapse sidebar',
                        icon: Icon(
                          collapsed
                              ? Icons.keyboard_double_arrow_right_rounded
                              : Icons.keyboard_double_arrow_left_rounded,
                        ),
                      );
                      return !collapsed
                          ? SizedBox(
                              width: 200,
                              child: Row(
                                children: [
                                  const Expanded(child: Wordmark()),
                                  toggle,
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                const Wordmark(),
                                const SizedBox(height: 10),
                                toggle,
                              ],
                            );
                    },
                  ),
                ),
                trailingAtBottom: true,
                trailing: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                  child: Builder(
                    builder: (context) {
                      final open = !collapsed;
                      return Column(
                        children: [
                          if (demo && open)
                            IndicatorTag(context.tr('Demo mode')),
                          if (open) const LanguageSwitchButton(),
                          const SizedBox(height: 6),
                          open
                              ? SizedBox(
                                  width: 200,
                                  child: TextButton.icon(
                                    onPressed: () => context.push(Routes.me),
                                    icon: const Icon(
                                      Icons.account_circle_outlined,
                                    ),
                                    label: Text(context.tr('Profile')),
                                  ),
                                )
                              : IconButton(
                                  onPressed: () => context.push(Routes.me),
                                  tooltip: context.tr('Profile'),
                                  icon: const Icon(
                                    Icons.account_circle_outlined,
                                  ),
                                ),
                        ],
                      );
                    },
                  ),
                ),
                selectedIndex: selected,
                onDestinationSelected: go,
                destinations: [
                  for (final item in _destinations)
                    NavigationRailDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selected),
                      label: Text(context.tr(item.label)),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(key: const ValueKey('active-screen'), child: widget.child),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: go,
              destinations: [
                for (final item in _destinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selected),
                    label: context.tr(item.label),
                  ),
              ],
            ),
    );
  }
}
