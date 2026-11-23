import 'calorie_range.dart';
import 'nutrient.dart';

const foodUnits = [
  'g',
  'ml',
  'cup',
  'piece',
  'serving',
  'tbsp',
  'tsp',
  'oz',
  'slice',
  'bowl',
];

class FoodItem {
  const FoodItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.range,
    this.grams,
    this.nutrients = const {},
    this.reference,
    this.nutrientSource = 'unavailable',
    this.provenance = 'manual',
  });
  final String name, unit, nutrientSource, provenance;
  final String? reference;
  final double quantity;
  final double? grams;
  final CalorieRange range;
  final Map<Nutrient, double?> nutrients;
  String get portion =>
      '${quantity == quantity.roundToDouble() ? quantity.toInt() : quantity} $unit';
  FoodItem scale(double next) {
    final ratio = next / quantity;
    double? scaled(double? value) =>
        value == null ? null : (value * ratio * 10).round() / 10;
    return FoodItem(
      name: name,
      quantity: next,
      unit: unit,
      range: CalorieRange(
        (range.low * ratio).round(),
        (range.high * ratio).round(),
      ),
      grams: scaled(grams),
      nutrients: {for (final n in Nutrient.values) n: scaled(nutrients[n])},
      reference: reference,
      nutrientSource: nutrientSource,
      provenance: 'scaled',
    );
  }
}
