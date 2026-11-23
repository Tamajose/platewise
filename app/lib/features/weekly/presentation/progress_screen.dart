import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/format/number_format.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/weekly_report.dart';
import 'summary_controller.dart';
import 'week_chart.dart';

/// The last seven days: calories against the target, nutrients and a summary.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(overviewProvider)
      .when(
        loading: () => const PageScroll(
          children: [LoadingState('Loading weekly progress…')],
        ),
        error: (e, _) => PageScroll(
          children: [
            ErrorState(
              failureMessage(e),
              retry: () => ref.invalidate(overviewProvider),
            ),
          ],
        ),
        data: (overview) {
          final report = WeeklyReport(overview.week);
          final date = DateFormat('MMM d');
          final average = report.average;
          final target = report.targetAverage;
          return PageScroll(
            maxWidth: 1080,
            children: [
              PageHeading(
                'Progress',
                eyebrow:
                    '${date.format(report.days.first.day)}–${date.format(report.days.last.day)}',
                detail: 'Your last seven local dates, including today.',
              ),
              const SizedBox(height: 12),
              if (overview.sampleHistory) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: IndicatorTag(
                    'Sample history',
                    icon: Icons.history_rounded,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              AdaptiveColumns(
                primary: WeekChart(report),
                secondary: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AdaptiveColumns(
                      breakpoint: 340,
                      primaryFlex: 1,
                      secondaryFlex: 1,
                      primary: MetricCard(
                        label: 'Meal coverage',
                        value: '${report.logged.length} / 7 days',
                        detail: 'Days with a confirmed meal',
                      ),
                      secondary: MetricCard(
                        label: 'Ranges on target',
                        value: report.paired.isEmpty
                            ? 'Unavailable'
                            : '${report.overlap} / ${report.paired.length} days',
                        detail: 'At least part of the range overlaps',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (average != null)
                            Text(
                              'Mean logged intake: ${number(average)} kcal on ${report.logged.length} days.',
                            ),
                          if (target != null)
                            Text(
                              'Mean target: ${number(target)} kcal across ${report.paired.length} logged days with a target.',
                            ),
                          const Text(
                            'A partial log cannot establish what you ate for the whole day.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              const SectionTitle(
                'Nutrients',
                detail:
                    'Estimated totals show how many items supplied each value.',
              ),
              const SizedBox(height: 7),
              NutrientBreakdown(report.items),
              const SizedBox(height: 15),
              _WeeklySummary(report),
              const SizedBox(height: 14),
              const DisclaimerNotice(),
            ],
          );
        },
      );
}

class _WeeklySummary extends ConsumerWidget {
  const _WeeklySummary(this.report);
  final WeeklyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (report.facts.isEmpty) {
      return const EmptyState(
        'More logs needed',
        'A weekly summary becomes available when meals are logged on at least two days.',
        icon: Icons.insights_rounded,
      );
    }
    final demo = ref.watch(sessionRepositoryProvider).isDemo;
    final key = report.facts.join('|');
    final state = ref.watch(summaryControllerProvider(key));
    final sentences = demo
        ? report.facts
        : state.summary?.sentences ?? const [];
    return Surface(
      color: PlateColors.sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            demo ? 'Weekly recap' : 'AI weekly summary',
            detail: demo
                ? 'Calculated from the displayed demo aggregates.'
                : 'Uses the counts and totals shown here.',
          ),
          const SizedBox(height: 8),
          for (final sentence in sentences)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(sentence),
            ),
          if (!demo && state.summary == null)
            SecondaryButton(
              'Generate weekly summary',
              icon: Icons.auto_awesome_outlined,
              onPressed: state.loading
                  ? null
                  : ref.read(summaryControllerProvider(key).notifier).generate,
            ),
          if (state.loading) const LoadingState('Preparing a short summary…'),
          if (state.error != null) ...[
            const SizedBox(height: 6),
            ErrorState(state.error!),
          ],
        ],
      ),
    );
  }
}
