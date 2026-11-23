import 'package:material_ui/material_ui.dart';

import '../domain/budget_fit.dart';
import '../theme/plate_theme.dart';
import 'indicators.dart';

/// Says whether a meal's calorie range fits a budget.
class BudgetFitBadge extends StatelessWidget {
  const BudgetFitBadge(this.fit, {super.key});
  final BudgetFit fit;

  @override
  Widget build(BuildContext context) {
    final calm = fit == BudgetFit.fits || fit == BudgetFit.noBudget;
    return IndicatorTag(
      fit.label,
      icon: fit == BudgetFit.fits
          ? Icons.check_circle_outline
          : Icons.info_outline,
      foreground: calm ? PlateColors.forest : PlateColors.amberInk,
      background: calm ? PlateColors.sage : PlateColors.amber,
    );
  }
}
