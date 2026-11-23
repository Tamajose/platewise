import 'dates.dart';
import 'day_log.dart';
import 'meal.dart';
import 'profile.dart';

class Overview {
  const Overview({
    this.profile,
    this.meals = const [],
    this.targets = const [],
    this.water = const [],
    this.localDay,
    this.pendingAssets = 0,
    this.deletionPending = false,
    this.deletionAccount = false,
    this.sampleHistory = false,
  });
  final Profile? profile;
  final List<SavedMeal> meals;
  final List<TargetSnapshot> targets;
  final List<WaterEntry> water;
  final DateTime? localDay;
  final int pendingAssets;
  final bool deletionPending, deletionAccount, sampleHistory;
  String get zone => profile?.zone ?? 'Asia/Dhaka';
  DayLog forDay(DateTime date) {
    final key = dayKey(date);
    int? target;
    for (final entry in targets) {
      if (entry.day.compareTo(key) <= 0) target = entry.target;
    }
    final dailyMeals =
        meals.where((m) => dayKey(localTime(m.at, zone)) == key).toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    final dailyWater =
        water.where((w) => dayKey(localTime(w.at, zone)) == key).toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    return DayLog(date, target, dailyMeals, dailyWater);
  }

  DateTime get todayDate => localDay ?? dayAt(localTime(DateTime.now(), zone));
  DayLog get today => forDay(todayDate);
  List<DayLog> get week =>
      List.generate(7, (index) => forDay(dayAt(todayDate, index - 6)));
}
