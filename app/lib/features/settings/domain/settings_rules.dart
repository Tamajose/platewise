import '../../../core/domain/calorie_range.dart';
import 'energy.dart';

const minEnergyAge = 19, maxEnergyAge = 78;

const energyInputMessage =
    'Confirm eligibility, enter an age from 19 to 78, and choose both settings.';

/// The age from typed text, or null when it is not in the supported range.
int? parseEnergyAge(String text) {
  final value = int.tryParse(text.trim());
  return value == null || value < minEnergyAge || value > maxEnergyAge
      ? null
      : value;
}

/// Foods a correction can be submitted for.
const correctionFoods = ['rice', 'dal', 'egg', 'chana', 'roti', 'khichuri'];

/// A correction from typed fields, or the message to show. The portion is in
/// grams (1 to 3,000) and the range in kcal (0 to 6,000).
({Correction? correction, String? error}) buildCorrection({
  required String food,
  required String grams,
  required String low,
  required String high,
}) {
  final portion = int.tryParse(grams.trim());
  final lowest = int.tryParse(low.trim());
  final highest = int.tryParse(high.trim());
  if (portion == null || portion < 1 || portion > 3000) {
    return (correction: null, error: 'Enter 1–3000.');
  }
  if (lowest == null || lowest < 0 || lowest > 6000) {
    return (correction: null, error: 'Enter 0–6000.');
  }
  if (highest == null || highest < 0 || highest > 6000) {
    return (correction: null, error: 'Enter 0–6000.');
  }
  if (lowest > highest) {
    return (
      correction: null,
      error: 'The high estimate must be at least the low estimate.',
    );
  }
  return (
    correction: (
      food: food,
      grams: portion,
      range: CalorieRange(lowest, highest),
    ),
    error: null,
  );
}
