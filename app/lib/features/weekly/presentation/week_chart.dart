import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/format/number_format.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/weekly_report.dart';

/// Seven days of logged calories beside the target, with a day-by-day list
/// that replaces the chart when text is scaled up.
class WeekChart extends StatelessWidget {
  const WeekChart(this.report, {super.key});
  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final days = report.days;
    final maximum = days.fold<int>(
      1000,
      (v, d) => math.max(v, math.max(d.representative, d.target ?? 0)),
    );
    final maxY = (maximum / 500).ceil() * 500.0 + 500;
    final date = DateFormat('EEE');
    final chartLabel =
        'Seven-day calorie chart. ${days.map((d) => '${date.format(d.day)} ${d.logged ? '${d.representative} kcal logged' : 'no meals logged'}, ${d.target == null ? 'no target' : '${d.target} kcal target'}').join('. ')}';
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Intake and target'),
          const SizedBox(height: 6),
          const Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _Legend(PlateColors.forest, 'Logged estimate'),
              _Legend(Color(0xFF9BAE98), 'Historical target'),
            ],
          ),
          if (report.logged.isEmpty) ...[
            const SizedBox(height: 10),
            const Text('No meals logged in this window.'),
          ],
          if (MediaQuery.textScalerOf(context).scale(13) <= 19) ...[
            const SizedBox(height: 14),
            Semantics(
              image: true,
              label: chartLabel,
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 165,
                  child: BarChart(
                    BarChartData(
                      maxY: maxY,
                      minY: 0,
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: 500,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: PlateColors.line,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: maxY > 3500 ? 2000 : 1000,
                            getTitlesWidget: (value, _) => Text(
                              value == 0
                                  ? '0'
                                  : '${(value / 1000).toStringAsFixed(0)}k',
                              style: theme.bodySmall,
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 23,
                            getTitlesWidget: (value, _) {
                              final i = value.toInt();
                              if (i < 0 || i >= days.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  date.format(days[i].day).substring(0, 1),
                                  style: theme.bodySmall,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(enabled: false),
                      barGroups: [
                        for (var i = 0; i < days.length; i++)
                          BarChartGroupData(
                            x: i,
                            barsSpace: 3,
                            barRods: [
                              BarChartRodData(
                                toY: days[i].logged
                                    ? days[i].representative.toDouble()
                                    : 0,
                                color: PlateColors.forest,
                                width: 9,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                              BarChartRodData(
                                toY: days[i].target?.toDouble() ?? 0,
                                color: const Color(0xFF9BAE98),
                                width: 5,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    duration: Duration.zero,
                  ),
                ),
              ),
            ),
          ],
          Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Day-by-day details'),
              initiallyExpanded:
                  MediaQuery.textScalerOf(context).scale(13) > 19,
              children: [
                for (final day in days)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(DateFormat('EEE, MMM d').format(day.day)),
                    subtitle: Text(
                      '${day.logged ? '${day.intake.label} kcal logged' : 'No meals logged'} · ${day.target == null ? 'No target' : '${number(day.target!)} kcal target'}'
                      '${day.targetRelation == null ? '' : ' · ${day.targetRelation}'}${day.waterMl == 0 ? '' : ' · ${number(day.waterMl)} ml water'}',
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

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Flexible(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
}
