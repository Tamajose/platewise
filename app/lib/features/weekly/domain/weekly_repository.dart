import 'weekly_report.dart';

abstract interface class WeeklyRepository {
  /// A short written summary of the week's logged counts and totals.
  Future<WeeklySummary> summary();
}
