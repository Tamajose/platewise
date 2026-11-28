import 'package:material_ui/material_ui.dart';

import '../../../core/domain/domain.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/decision.dart';
import '../../../core/l10n/l10n.dart';

/// The ranked options, any that failed, and a way to retry.
class DecisionResults extends StatelessWidget {
  const DecisionResults(
    this.result, {
    super.key,
    required this.budget,
    required this.choose,
    this.onRetry,
  });

  final DecisionResult result;
  final int? budget;
  final void Function(RankedMeal) choose;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionTitle(
        context.tr('Comparison results'),
        detail: budget == null
            ? context.tr('No meal budget selected')
            : context.tr('{p0} kcal meal budget', {
                'p0': context.number(budget!),
              }),
      ),
      const SizedBox(height: 8),
      if (result.meals.length == 1)
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            context.tr(
              'One option was estimated. Review it while you retry the others.',
            ),
          ),
        ),
      for (final failure in result.failures) ...[
        ErrorState(
          context.tr('Option {p0} · {p1}', {
            'p0': (int.tryParse(failure.key) ?? 0) + 1,
            'p1': failure.message,
          }),
        ),
        const SizedBox(height: 7),
      ],
      if (result.failures.isNotEmpty && onRetry != null)
        SecondaryButton(context.tr('Retry comparison'), onPressed: onRetry),
      LayoutBuilder(
        builder: (context, size) {
          final count = result.meals.length;
          final wide =
              count >= 2 &&
              size.maxWidth >= count * 257 &&
              MediaQuery.textScalerOf(context).scale(14) <= 20;
          final width = wide
              ? (size.maxWidth - (count - 1) * 10) / count
              : size.maxWidth;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final candidate in result.meals)
                SizedBox(
                  width: width,
                  child: RankedMealCard(
                    candidate,
                    best:
                        candidate.rank == 1 &&
                        candidate.fit == BudgetFit.fits &&
                        count >= 2,
                    onChoose: () => choose(candidate),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 10),
      const DisclaimerNotice(),
    ],
  );
}

class RankedMealCard extends StatelessWidget {
  const RankedMealCard(
    this.meal, {
    super.key,
    required this.onChoose,
    this.best = false,
  });

  final RankedMeal meal;
  final VoidCallback onChoose;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final draft = meal.draft;
    final nutrients = nutrientTotals(draft.items);
    final protein = nutrients[Nutrient.protein]!.value;
    return Surface(
      color: best ? PlateColors.sage : PlateColors.surface,
      border: best ? const Color(0xFF9FB88F) : PlateColors.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Rank {p0}{p1}', {
              'p0': meal.rank,
              'p1': best ? context.tr(' · Best fit for your budget') : '',
            }),
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: PlateColors.forest),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(draft.title),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          Text(
            context.tr('{p0} kcal', {'p0': draft.range.label}),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Text(draft.items.map((item) => item.portion).join(' + ')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              BudgetFitBadge(meal.fit),
              ConfidenceBadge(draft.confidence),
            ],
          ),
          const SizedBox(height: 8),
          Text(meal.reason),
          if (draft.assumptions.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              draft.assumptions.first,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 5),
          Text(
            protein != null
                ? context.tr('Estimated protein · {p0} g ({p1}/{p2} items)', {
                    'p0': protein.toStringAsFixed(1),
                    'p1': nutrients[Nutrient.protein]!.known,
                    'p2': draft.items.length,
                  })
                : context.tr('Protein estimate unavailable'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: best
                ? PrimaryButton(
                    context.tr('Choose this meal'),
                    onPressed: onChoose,
                  )
                : SecondaryButton(
                    context.tr('Choose this meal'),
                    onPressed: onChoose,
                  ),
          ),
        ],
      ),
    );
  }
}
