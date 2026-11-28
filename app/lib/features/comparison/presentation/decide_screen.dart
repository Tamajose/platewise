import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/domain/domain.dart';
import '../../../core/presentation/photo_source_sheet.dart';
import '../../../core/presentation/routes.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/decision.dart';
import 'decide_controller.dart';
import 'decision_results.dart';
import 'small_budget_note.dart';
import '../../../core/l10n/l10n.dart';

/// Compare meals before choosing: dishes from a menu, or two or three photos.
class DecideScreen extends ConsumerStatefulWidget {
  const DecideScreen({super.key});

  @override
  ConsumerState<DecideScreen> createState() => _DecideScreenState();
}

class _DecideScreenState extends ConsumerState<DecideScreen> {
  final budget = TextEditingController();

  @override
  void dispose() {
    budget.dispose();
    super.dispose();
  }

  DecideController get controller =>
      ref.read(decideControllerProvider.notifier);

  Future<void> pick(int index) async {
    final source = await choosePhotoSource(context);
    if (source == null || !mounted) return;
    await controller.pickPhoto(index, source);
  }

  Future<void> openMenu({bool scan = false, bool sample = false}) async {
    PhotoSource? source;
    if (scan) {
      source = await choosePhotoSource(context);
      if (source == null || !mounted) return;
    }
    final args = await controller.prepareMenu(scan: source, sample: sample);
    if (args == null || !mounted) return;
    await context.push(Routes.menuReview, extra: args);
  }

  Future<void> choose(RankedMeal meal) async {
    final saved = await context.push<bool>(
      Routes.review,
      extra: controller.reviewFor(meal),
    );
    if (saved == true && mounted) {
      controller.finishChoice();
      context.go(Routes.today);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(decideControllerProvider);
    final demo = ref.watch(sessionRepositoryProvider).isDemo;
    final remaining = suggestedBudget(ref.watch(overviewProvider).value);
    final budgetNow = state.useRemaining
        ? remaining
        : int.tryParse(state.budgetText.trim());
    return PageScroll(
      maxWidth: 1080,
      children: [
        PageHeading(
          context.tr('Decide'),
          detail: context.tr(
            'Compare portions and calorie ranges before you choose.',
          ),
        ),
        const SizedBox(height: 15),
        Surface(
          color: PlateColors.sage,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconTile(
                Icons.track_changes_rounded,
                color: PlateColors.forest,
                ink: Colors.white,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Meal budget'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      state.useRemaining
                          ? (remaining == null
                                ? context.tr(
                                    'No positive daily budget available',
                                  )
                                : context.tr('{p0} kcal remaining today', {
                                    'p0': context.number(remaining),
                                  }))
                          : context.tr('Set a budget for this meal'),
                    ),
                    if (!state.useRemaining) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: budget,
                        enabled: !state.busy,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.tr('Meal budget (kcal)'),
                          hintText: context.tr('Optional'),
                        ),
                        onChanged: controller.setBudgetText,
                      ),
                    ],
                    SmallBudgetNote(budgetNow),
                    TextButton(
                      onPressed: state.busy
                          ? null
                          : controller.toggleBudgetMode,
                      child: Text(
                        state.useRemaining
                            ? context.tr('Set a meal budget')
                            : context.tr('Use today’s remaining budget'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                context.tr('Plan a dish'),
                detail: context.tr(
                  'Name a dish you plan to cook for a suggested portion and possible recipe adjustments within your budget.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !state.recommendationBusy,
                onChanged: controller.setDishText,
                maxLength: 300,
                buildCounter: context.counterBuilder,
                decoration: InputDecoration(
                  labelText: context.tr('Dish you plan to cook'),
                  hintText: context.tr('For example, chicken curry with rice'),
                ),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                context.tr('Suggest a portion'),
                icon: Icons.soup_kitchen_outlined,
                busy: state.recommendationBusy,
                onPressed: controller.recommendDish,
              ),
              if (state.recommendationBusy)
                Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LoadingState(context.tr('Planning a portion…')),
                ),
              if (state.recommendationError != null) ...[
                const SizedBox(height: 10),
                ErrorState(state.recommendationError!),
              ],
              if (state.recommendation case final recommendation?) ...[
                const SizedBox(height: 14),
                Surface(
                  color: PlateColors.sage,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('Suggested portion'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recommendation.portion,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        context.tr('{p0} kcal estimated · {p1} kcal budget', {
                          'p0': recommendation.range.label,
                          'p1': context.number(state.recommendationBudget!),
                        }),
                      ),
                      if (recommendation.adjustments.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          context.tr('Possible recipe adjustments'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        for (final adjustment in recommendation.adjustments)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text('• $adjustment'),
                          ),
                      ],
                      if (recommendation.assumptions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          context.tr('Assumptions'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        for (final assumption in recommendation.assumptions)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(assumption),
                          ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        context.tr(
                          'Nutrition values are estimates, not guarantees or individualized medical advice. This plan has not been logged.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        AdaptiveColumns(
          primaryFlex: 5,
          secondaryFlex: 6,
          primary: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(
                  context.tr('Compare from a menu'),
                  detail: context.tr(
                    'Review dish names and portions before comparing.',
                  ),
                ),
                const SizedBox(height: 14),
                if (demo) ...[
                  PrimaryButton(
                    context.tr('Review sample menu'),
                    icon: Icons.restaurant_menu_rounded,
                    onPressed: state.busy ? null : () => openMenu(sample: true),
                  ),
                  const SizedBox(height: 8),
                ],
                SecondaryButton(
                  context.tr('Choose menu photo'),
                  icon: Icons.photo_library_outlined,
                  onPressed: state.busy ? null : () => openMenu(scan: true),
                ),
                TextButton(
                  onPressed: state.busy ? null : openMenu,
                  child: Text(context.tr('Type menu dishes')),
                ),
              ],
            ),
          ),
          secondary: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(
                  context.tr('Compare meal photos'),
                  detail: context.tr('Add two or three options.'),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < state.photos.length; i++) ...[
                  Surface(
                    color: PlateColors.canvas,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        if (state.photos[i] != null)
                          SizedBox(
                            width: 54,
                            child: FoodPicture(
                              bytes: state.photos[i],
                              height: 48,
                            ),
                          )
                        else
                          const IconTile(Icons.add_a_photo_outlined),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.photos[i] == null
                                ? context.tr('Meal option {p0}', {'p0': i + 1})
                                : context.tr('Photo {p0} added', {'p0': i + 1}),
                          ),
                        ),
                        IconButton(
                          onPressed: state.busy ? null : () => pick(i),
                          icon: Icon(
                            state.photos[i] == null
                                ? Icons.add
                                : Icons.edit_outlined,
                          ),
                          tooltip: state.photos[i] == null
                              ? context.tr('Add photo {p0}', {'p0': i + 1})
                              : context.tr('Replace photo {p0}', {'p0': i + 1}),
                        ),
                        if (state.photos[i] != null || i == 2)
                          IconButton(
                            onPressed: state.busy
                                ? null
                                : () => controller.removePhoto(i),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: context.tr('Remove option {p0}', {
                              'p0': i + 1,
                            }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (state.canAddOption)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: state.busy ? null : controller.addOption,
                      icon: const Icon(Icons.add),
                      label: Text(context.tr('Add a third option')),
                    ),
                  ),
                PrimaryButton(
                  context.tr('Compare photos'),
                  icon: Icons.compare_arrows_rounded,
                  busy: state.busy,
                  onPressed: state.canComparePhotos
                      ? controller.comparePhotos
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (state.busy) LoadingState(context.tr('Working on your options…')),
        if (state.error != null) ...[
          const SizedBox(height: 10),
          ErrorState(state.error!),
        ],
        if (state.result != null) ...[
          const SizedBox(height: 16),
          DecisionResults(
            state.result!,
            budget: state.resultBudget,
            choose: choose,
            onRetry: state.busy ? null : controller.comparePhotos,
          ),
        ],
        if (state.result == null) ...[
          const SizedBox(height: 14),
          const DisclaimerNotice(),
        ],
      ],
    );
  }
}
