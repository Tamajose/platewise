import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/domain/domain.dart';
import '../../../core/presentation/review_args.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'food_estimate_editor.dart';
import 'review_controller.dart';
import '../../../core/l10n/l10n.dart';

/// Check a meal estimate, change its foods and portions, and log it. Also used
/// to edit a meal that is already in the log.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen(this.args, {super.key});
  final ReviewArgs args;

  Future<void> editFood(
    BuildContext context,
    WidgetRef ref,
    ReviewState state, [
    int? index,
  ]) async {
    final next = await showModalBottomSheet<FoodItem>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FoodEstimateEditor(
        initial: index == null ? null : state.draft.items[index],
      ),
    );
    if (next == null || !context.mounted) return;
    ref.read(reviewControllerProvider(args).notifier).putFood(index, next);
  }

  Future<void> save(BuildContext context, WidgetRef ref, bool wasSaved) async {
    final saved = await ref
        .read(reviewControllerProvider(args).notifier)
        .save();
    if (!saved || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasSaved
              ? context.tr('Meal updated')
              : context.tr('Meal added to Today'),
        ),
      ),
    );
    context.pop(true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reviewControllerProvider(args));
    final controller = ref.read(reviewControllerProvider(args).notifier);
    final draft = state.draft;
    final image = draft.isSaved && draft.imagePath != null
        ? ref.watch(mealImageProvider(draft.id))
        : null;
    return PopScope<bool>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) controller.discardIfAbandoned();
      },
      child: Standalone(
        title: draft.isSaved
            ? context.tr('Edit meal')
            : context.tr('Review meal'),
        bottom: PrimaryButton(
          draft.isSaved
              ? context.tr('Save changes')
              : context.tr('Confirm and log meal'),
          icon: Icons.check_rounded,
          busy: state.busy,
          onPressed: state.canSave
              ? () => save(context, ref, draft.isSaved)
              : null,
        ),
        body: PageScroll(
          children: [
            PageHeading(
              draft.isSaved
                  ? context.tr('Saved meal')
                  : context.tr('Check your estimate'),
              detail: draft.isSaved
                  ? context.tr('Changes update your daily and weekly log.')
                  : context.tr(
                      'This draft enters your log when you confirm it.',
                    ),
            ),
            const SizedBox(height: 14),
            if (args.photo != null || args.editorial) ...[
              FoodPicture(bytes: args.photo, editorial: args.editorial),
              const SizedBox(height: 12),
            ],
            if (image != null) ...[
              image.when(
                data: (url) => FoodPicture(url: url),
                loading: () =>
                    LoadingState(context.tr('Loading your private photo…')),
                error: (_, _) => ErrorState(
                  context.tr('The saved photo could not be opened.'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Surface(
              color: PlateColors.sage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('{p0} · estimated total', {
                      'p0': draft.source.label,
                    }),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.tr('{p0} kcal', {'p0': draft.range.label}),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 7),
                  ConfidenceBadge(draft.confidence),
                  if (draft.model == 'demo-fixtures')
                    Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Text(context.tr('Illustrative demo estimate')),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const DisclaimerNotice(),
            const SizedBox(height: 17),
            SectionTitle(context.tr('Foods and portions')),
            const SizedBox(height: 8),
            if (draft.items.isEmpty)
              EmptyState(
                context.tr('Add a food'),
                context.tr(
                  'Enter the portion and a calorie range from a label or your estimate.',
                ),
              ),
            for (var index = 0; index < draft.items.length; index++) ...[
              Surface(
                padding: const EdgeInsets.fromLTRB(12, 7, 4, 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.tr(draft.items[index].name)),
                          subtitle: Text(
                            context.tr('{p0} · {p1} kcal', {
                              'p0': draft.items[index].portion,
                              'p1': draft.items[index].range.label,
                            }),
                          ),
                          onTap: state.busy
                              ? null
                              : () => editFood(context, ref, state, index),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('Edit {p0}', {
                        'p0': draft.items[index].name,
                      }),
                      onPressed: state.busy
                          ? null
                          : () => editFood(context, ref, state, index),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: context.tr('Remove {p0}', {
                        'p0': draft.items[index].name,
                      }),
                      onPressed: state.busy
                          ? null
                          : () => controller.removeFood(index),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
            ],
            if (state.canAddFood)
              SecondaryButton(
                context.tr('Add food'),
                icon: Icons.add,
                onPressed: state.busy
                    ? null
                    : () => editFood(context, ref, state),
              ),
            if (draft.items.isNotEmpty) ...[
              const SizedBox(height: 17),
              SectionTitle(context.tr('Nutrient estimates')),
              const SizedBox(height: 8),
              NutrientBreakdown(draft.items),
            ],
            if (draft.assumptions.isNotEmpty || draft.question != null) ...[
              const SizedBox(height: 17),
              SectionTitle(context.tr('Assumptions')),
              const SizedBox(height: 6),
              for (final entry in draft.assumptions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $entry'),
                ),
              if (draft.question != null) Text(draft.question!),
            ],
            const SizedBox(height: 12),
            Text(
              draft.confidence == Confidence.low
                  ? context.tr(
                      'Low confidence means portions or composition are uncertain. Check details against what you ate.',
                    )
                  : context.tr(
                      'Medium confidence is an estimate with recognizable foods and plausible portions. Check it against what you ate.',
                    ),
            ),
            if (state.tooLarge)
              ErrorState(
                context.tr(
                  'The total range exceeds the supported meal size. Check the entered quantities.',
                ),
              ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              ErrorState(state.error!),
            ],
          ],
        ),
      ),
    );
  }
}
