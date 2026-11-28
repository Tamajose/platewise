import 'package:material_ui/material_ui.dart';

import '../domain/food_item.dart';
import '../l10n/l10n.dart';
import '../domain/nutrient.dart';
import 'layout.dart';

/// Nutrient totals for a meal. A nutrient that no item reports shows as
/// unavailable, and a partial total says how many items it covers.
class NutrientBreakdown extends StatelessWidget {
  const NutrientBreakdown(this.items, {super.key});
  final Iterable<FoodItem> items;

  @override
  Widget build(BuildContext context) {
    final data = nutrientTotals(items);
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final nutrient in Nutrient.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(context.tr(nutrient.label))),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      data[nutrient]!.value == null
                          ? context.tr('Unavailable')
                          : context.tr('≈{p0} {p1}  ·  {p2}/{p3} items', {
                              'p0': context.number(
                                double.parse(
                                  data[nutrient]!.value!.toStringAsFixed(1),
                                ),
                              ),
                              'p1': nutrient.unit,
                              'p2': data[nutrient]!.known,
                              'p3': data[nutrient]!.total,
                            }),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
