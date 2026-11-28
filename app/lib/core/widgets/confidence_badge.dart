import 'package:material_ui/material_ui.dart';

import '../domain/meal.dart';
import '../theme/plate_theme.dart';
import 'indicators.dart';
import '../../core/l10n/l10n.dart';

/// Shows how sure an estimate is. Low confidence uses the warning colors.
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge(this.confidence, {super.key});
  final Confidence confidence;

  @override
  Widget build(BuildContext context) => IndicatorTag(
    context.tr(switch (confidence) {
      Confidence.high => 'High confidence',
      Confidence.medium => 'Medium confidence',
      Confidence.low => 'Low confidence',
    }),
    icon: Icons.signal_cellular_alt_2_bar_rounded,
    foreground: confidence == Confidence.low
        ? PlateColors.amberInk
        : PlateColors.forest,
    background: confidence == Confidence.low
        ? PlateColors.amber
        : PlateColors.sage,
  );
}
