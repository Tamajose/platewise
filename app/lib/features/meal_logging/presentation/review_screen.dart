import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/domain/domain.dart';
import '../../../core/presentation/review_args.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'food_estimate_editor.dart';
import 'review_controller.dart';

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
        content: Text(wasSaved ? 'Meal updated' : 'Meal added to Today'),
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
        title: draft.isSaved ? 'Edit meal' : 'Review meal',
        bottom: PrimaryButton(
          draft.isSaved ? 'Save changes' : 'Confirm and log meal',
          icon: Icons.check_rounded,
          busy: state.busy,
          onPressed: state.canSave
              ? () => save(context, ref, draft.isSaved)
              : null,
        ),
        body: PageScroll(
          children: [
            PageHeading(
              draft.isSaved ? 'Saved meal' : 'Check your estimate',
              detail: draft.isSaved
                  ? 'Changes update your daily and weekly log.'
                  : 'This draft enters your log when you confirm it.',
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
                    const LoadingState('Loading your private photo…'),
                error: (_, _) =>
                    const ErrorState('The saved photo could not be opened.'),
              ),
              const SizedBox(height: 12),
            ],
            Surface(
              color: PlateColors.sage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${draft.source.label} · estimated total',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${draft.range.label} kcal',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 7),
                  ConfidenceBadge(draft.confidence),
                  if (draft.model == 'demo-fixtures')
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Text('Illustrative demo estimate'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const DisclaimerNotice(),
            const SizedBox(height: 17),
            const SectionTitle('Foods and portions'),
            const SizedBox(height: 8),
            if (draft.items.isEmpty)
              const EmptyState(
                'Add a food',
                'Enter the portion and a calorie range from a label or your estimate.',
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
                          title: Text(draft.items[index].name),
                          subtitle: Text(
                            '${draft.items[index].portion} · ${draft.items[index].range.label} kcal',
                          ),
                          onTap: state.busy
                              ? null
                              : () => editFood(context, ref, state, index),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit ${draft.items[index].name}',
                      onPressed: state.busy
                          ? null
                          : () => editFood(context, ref, state, index),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Remove ${draft.items[index].name}',
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
                'Add food',
                icon: Icons.add,
                onPressed: state.busy
                    ? null
                    : () => editFood(context, ref, state),
              ),
            if (draft.items.isNotEmpty) ...[
              const SizedBox(height: 17),
              const SectionTitle('Nutrient estimates'),
              const SizedBox(height: 8),
              NutrientBreakdown(draft.items),
            ],
            if (draft.assumptions.isNotEmpty || draft.question != null) ...[
              const SizedBox(height: 17),
              const SectionTitle('Assumptions'),
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
                  ? 'Low confidence means portions or composition are uncertain. Check details against what you ate.'
                  : 'Medium confidence is an estimate with recognizable foods and plausible portions. Check it against what you ate.',
            ),
            if (state.tooLarge)
              const ErrorState(
                'The total range exceeds the supported meal size. Check the entered quantities.',
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
