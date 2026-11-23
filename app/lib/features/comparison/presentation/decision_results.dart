import 'package:material_ui/material_ui.dart';

import '../../../core/domain/domain.dart';
import '../../../core/format/number_format.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/decision.dart';

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
        'Comparison results',
        detail: budget == null
            ? 'No meal budget selected'
            : '${number(budget!)} kcal meal budget',
      ),
      const SizedBox(height: 8),
      if (result.meals.length == 1)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'One option was estimated. Review it while you retry the others.',
          ),
        ),
      for (final failure in result.failures) ...[
        ErrorState(
          'Option ${(int.tryParse(failure.key) ?? 0) + 1} · ${failure.message}',
        ),
        const SizedBox(height: 7),
      ],
      if (result.failures.isNotEmpty && onRetry != null)
        SecondaryButton('Retry comparison', onPressed: onRetry),
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
            'Rank ${meal.rank}${best ? ' · Best fit for your budget' : ''}',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: PlateColors.forest),
          ),
          const SizedBox(height: 4),
          Text(draft.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 7),
          Text(
            '${draft.range.label} kcal',
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
                ? 'Estimated protein · ${protein.toStringAsFixed(1)} g (${nutrients[Nutrient.protein]!.known}/${draft.items.length} items)'
                : 'Protein estimate unavailable',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: best
                ? PrimaryButton('Choose this meal', onPressed: onChoose)
                : SecondaryButton('Choose this meal', onPressed: onChoose),
          ),
        ],
      ),
    );
  }
}
