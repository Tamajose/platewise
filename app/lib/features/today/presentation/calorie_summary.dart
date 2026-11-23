import 'package:material_ui/material_ui.dart';

import '../../../core/domain/domain.dart';
import '../../../core/format/number_format.dart';
import '../../../core/theme/plate_theme.dart';

/// Calories logged against the daily target, as numbers and a ring.
class CalorieSummary extends StatelessWidget {
  const CalorieSummary(this.log, {super.key});
  final DayLog log;

  @override
  Widget build(BuildContext context) {
    final target = log.target, consumed = log.representative;
    final remaining = target == null ? null : target - consumed;
    final aboveTarget = remaining != null && remaining < 0;
    final progress = target != null && target > 0 ? consumed / target : null;
    final accent = aboveTarget ? const Color(0xFFFFCF94) : PlateColors.lime;
    final style = Theme.of(context).textTheme;
    final detail = target == null
        ? 'Set a target in Settings'
        : '${number(consumed)} logged · ${number(target)} target';
    return Container(
      decoration: const BoxDecoration(
        color: PlateColors.deep,
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, size) {
              final showRim =
                  progress != null &&
                  size.maxWidth >= 238 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 20;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily calorie estimate',
                              style: style.labelLarge?.copyWith(
                                color: const Color(0xFFE0E9DA),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              number(remaining?.abs() ?? consumed),
                              style: style.displaySmall?.copyWith(
                                color: accent,
                              ),
                            ),
                            Text(
                              target == null
                                  ? 'kcal logged'
                                  : aboveTarget
                                  ? 'kcal above target'
                                  : 'kcal remaining',
                              style: style.bodyMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showRim) ...[
                        const SizedBox(width: 12),
                        _PlateGauge(
                          progress,
                          accent,
                          size.maxWidth >= 400 ? 120 : 84,
                        ),
                      ],
                    ],
                  ),
                  if (progress != null && !showRim) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress.clamp(0, 1).toDouble(),
                      color: accent,
                      backgroundColor: const Color(0xFF527060),
                      semanticsLabel: 'Daily calorie target logged',
                    ),
                  ],
                ],
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 11),
            child: Divider(color: Color(0xFF567D68)),
          ),
          Text(detail, style: style.labelLarge?.copyWith(color: Colors.white)),
          const SizedBox(height: 3),
          Text(
            log.logged
                ? 'Intake range · ${log.intake.label} kcal'
                : 'Estimates appear after your first confirmed meal.',
            style: style.bodySmall?.copyWith(color: const Color(0xFFDEF0E0)),
          ),
          if (target != null && log.logged)
            Text(
              'Remaining range · ${log.intake.remaining(target).label} kcal',
              style: style.bodySmall?.copyWith(color: const Color(0xFFDEF0E0)),
            ),
        ],
      ),
    );
  }
}

class _PlateGauge extends StatelessWidget {
  const _PlateGauge(this.progress, this.color, this.size);
  final double progress, size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).round();
    return Semantics(
      label: '$percentage percent of target logged',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: progress.clamp(0, 1).toDouble(),
              strokeWidth: 5,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: const Color(0xFF527060),
            ),
            Padding(
              padding: const EdgeInsets.all(11),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF6B8675)),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$percentage%',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: color),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
