import 'dart:math' as math;

import '../../../core/domain/domain.dart';

/// The shortest and longest stretch of days a person can export.
const minExportDays = 7;
const maxExportDays = 365;

/// How many days an export covers. A request is never shorter than a week and
/// never reaches back past the first day with a record, so an account that
/// began three weeks ago exports at most three weeks even when a year is asked
/// for.
int exportWindow(int requested, int available) => math.min(
  requested.clamp(minExportDays, maxExportDays),
  math.max(minExportDays, available),
);

/// One day of exported statistics.
class ExportRow {
  const ExportRow(this.day, this.log);
  final DateTime day;
  final DayLog log;
}

/// The days a person chose to export, with the figures behind each.
class StatsExport {
  const StatsExport({
    required this.overview,
    required this.requestedDays,
    required this.days,
    required this.availableDays,
  });

  /// Builds an export from an [overview] that already holds the whole window.
  factory StatsExport.fromOverview(Overview overview, int requested) {
    final today = overview.todayDate;
    int? first;
    for (final entry in [
      ...overview.meals.map((m) => localTime(m.at, overview.zone)),
      ...overview.water.map((w) => localTime(w.at, overview.zone)),
    ]) {
      final age = today.difference(dayAt(entry)).inDays + 1;
      if (first == null || age > first) first = age;
    }
    final available = first ?? 0;
    return StatsExport(
      overview: overview,
      requestedDays: requested,
      days: exportWindow(requested, available),
      availableDays: available,
    );
  }

  final Overview overview;
  final int requestedDays, days, availableDays;

  /// Whether fewer days were exported than asked for, because the older ones
  /// hold no records.
  bool get shortened => days < requestedDays;

  List<ExportRow> get rows {
    final today = overview.todayDate;
    return [
      for (var i = 0; i < days; i++)
        () {
          final day = dayAt(today, i - (days - 1));
          return ExportRow(day, overview.forDay(day));
        }(),
    ];
  }

  int get mealCount => rows.fold(0, (sum, row) => sum + row.log.meals.length);
  int get loggedDays => rows.where((row) => row.log.logged).length;

  /// Daily figures as comma-separated text that opens in any spreadsheet.
  /// Calories are estimates, so each day carries its range and its midpoint.
  String toCsv() {
    final out = StringBuffer(
      'date,target_kcal,meals,kcal_low,kcal_high,kcal_estimate,target_comparison,water_ml\r\n',
    );
    for (final row in rows) {
      final log = row.log;
      out.write(
        [
          dayKey(row.day),
          log.target ?? '',
          log.meals.length,
          log.logged ? log.intake.low : '',
          log.logged ? log.intake.high : '',
          log.logged ? log.representative : '',
          log.targetRelation?.toLowerCase() ?? '',
          log.waterMl,
        ].join(','),
      );
      out.write('\r\n');
    }
    return out.toString();
  }

  /// A file name that says which days the export holds.
  String get fileName {
    final rows = this.rows;
    return 'platewise-stats-${dayKey(rows.first.day)}-to-${dayKey(rows.last.day)}.csv';
  }
}
