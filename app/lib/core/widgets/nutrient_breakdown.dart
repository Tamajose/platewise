import 'package:material_ui/material_ui.dart';

import '../domain/food_item.dart';
import '../domain/nutrient.dart';
import '../format/number_format.dart';
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
                  Expanded(child: Text(nutrient.label)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      data[nutrient]!.value == null
                          ? 'Unavailable'
                          : '≈${number(double.parse(data[nutrient]!.value!.toStringAsFixed(1)))} ${nutrient.unit}  ·  ${data[nutrient]!.known}/${data[nutrient]!.total} items',
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
