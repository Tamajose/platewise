import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/domain/domain.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/routes.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/widgets/widgets.dart';
import 'calorie_summary.dart';
import 'meal_list_item.dart';
import 'today_controller.dart';

/// Builds the water quick-add for [log]. The app supplies it, because water
/// belongs to another feature and features cannot import each other.
typedef WaterQuickAddBuilder = Widget Function(DayLog log, int goal);

/// The daily log: calories against the target, today's meals, and shortcuts to
/// log a meal or compare options.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key, this.waterQuickAdd});

  final WaterQuickAddBuilder? waterQuickAdd;

  Future<void> retryCleanup(BuildContext context, WidgetRef ref) async {
    final error = await ref.read(todayActionsProvider).retryPhotoCleanup();
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(overviewProvider);
    return state.when(
      loading: () =>
          const PageScroll(children: [LoadingState('Opening your log…')]),
      error: (e, _) => PageScroll(
        children: [
          ErrorState(
            failureMessage(e),
            retry: () => ref.invalidate(overviewProvider),
          ),
        ],
      ),
      data: (data) {
        final today = data.today;
        final water = waterQuickAdd?.call(
          today,
          data.profile?.waterGoal ?? 2000,
        );
        return PageScroll(
          maxWidth: 1080,
          onRefresh: () async {
            ref.invalidate(overviewProvider);
            await ref.read(overviewProvider.future);
          },
          children: [
            PageHeading(
              'Today',
              eyebrow: DateFormat('EEEE, MMMM d').format(today.day),
            ),
            const SizedBox(height: 20),
            AdaptiveColumns(
              primary: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CalorieSummary(today),
                  const SizedBox(height: 12),
                  AdaptiveColumns(
                    breakpoint: 335,
                    primaryFlex: 1,
                    secondaryFlex: 1,
                    primary: PrimaryButton(
                      'Compare meals',
                      icon: Icons.compare_arrows_rounded,
                      onPressed: () => context.go(Routes.decide),
                    ),
                    secondary: SecondaryButton(
                      'Log meal',
                      icon: Icons.add_rounded,
                      onPressed: () => context.push(Routes.log),
                    ),
                  ),
                ],
              ),
              secondary: water ?? const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            const SectionTitle('Meals today'),
            const SizedBox(height: 9),
            if (today.meals.isEmpty)
              const EmptyState(
                'No meals logged yet',
                'Add a meal to see your estimated intake here.',
              )
            else
              Surface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < today.meals.length; i++) ...[
                      if (i != 0) const Divider(indent: 50),
                      MealListItem(today.meals[i], data.zone),
                    ],
                  ],
                ),
              ),
            if (data.pendingAssets > 0) ...[
              const SizedBox(height: 11),
              ErrorState(
                'A removed photo is still pending cleanup.',
                retry: () => retryCleanup(context, ref),
              ),
            ],
            const SizedBox(height: 14),
            const DisclaimerNotice(),
          ],
        );
      },
    );
  }
}
