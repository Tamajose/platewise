import 'calorie_range.dart';
import 'meal.dart';

class TargetSnapshot {
  const TargetSnapshot(this.day, this.target);
  final String day;
  final int? target;
}

class WaterEntry {
  const WaterEntry(this.id, this.at, this.amount, this.revision);
  final String id, revision;
  final DateTime at;
  final int amount;
}

class DayLog {
  const DayLog(this.day, this.target, this.meals, this.water);
  final DateTime day;
  final int? target;
  final List<SavedMeal> meals;
  final List<WaterEntry> water;
  bool get logged => meals.isNotEmpty;
  CalorieRange get intake =>
      meals.fold(CalorieRange.zero, (sum, m) => sum + m.range);
  int get representative => meals.fold(0, (sum, m) => sum + m.representative);
  int get waterMl => water.fold(0, (sum, entry) => sum + entry.amount);
  String? get targetRelation {
    final limit = target;
    if (!logged || limit == null) return null;
    if (intake.high < limit) return 'Below';
    if (intake.low > limit) return 'Above';
    return 'Overlaps';
  }
}
