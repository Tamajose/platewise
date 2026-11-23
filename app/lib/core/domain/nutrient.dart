import 'food_item.dart';

enum Nutrient {
  protein('Protein', 'protein_g', 'g'),
  carbohydrate('Carbohydrate', 'carbohydrate_g', 'g'),
  fat('Fat', 'fat_g', 'g'),
  fiber('Fibre', 'fiber_g', 'g'),
  sodium('Sodium', 'sodium_mg', 'mg');

  const Nutrient(this.label, this.key, this.unit);

  /// [key] is the wire name of the nutrient in the API. Mappers use it.
  final String label, key, unit;
}

typedef NutrientAmount = ({double? value, int known, int total});

Map<Nutrient, NutrientAmount> nutrientTotals(Iterable<FoodItem> items) {
  final all = items.toList();
  return {
    for (final nutrient in Nutrient.values)
      nutrient: (() {
        final known = all.map((i) => i.nutrients[nutrient]).nonNulls.toList();
        return (
          value: known.isEmpty ? null : known.fold(0.0, (a, b) => a + b),
          known: known.length,
          total: all.length,
        );
      })(),
  };
}
