import 'package:material_ui/material_ui.dart';

import '../../../core/domain/domain.dart';
import '../../../core/theme/plate_theme.dart';

/// A plain note beside a budget too small for a meal. It states the situation
/// and what is still possible. It shows nothing for any other budget.
class SmallBudgetNote extends StatelessWidget {
  const SmallBudgetNote(this.budget, {super.key});
  final int? budget;

  @override
  Widget build(BuildContext context) {
    if (!isSmallBudget(budget)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 17,
            color: PlateColors.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              smallBudgetNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
