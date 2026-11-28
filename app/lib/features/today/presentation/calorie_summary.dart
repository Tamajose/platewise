import 'package:material_ui/material_ui.dart';

import '../../../core/domain/domain.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/l10n/l10n.dart';

/// Calories logged against the daily target: one large number, a thin bar and
/// the ranges behind it.
class CalorieSummary extends StatelessWidget {
  const CalorieSummary(this.log, {super.key});
  final DayLog log;

  @override
  Widget build(BuildContext context) {
    final target = log.target, consumed = log.representative;
    final remaining = target == null ? null : target - consumed;
    final aboveTarget = remaining != null && remaining < 0;
    final progress = target != null && target > 0 ? consumed / target : null;
    final accent = aboveTarget ? PlateColors.amberInk : PlateColors.forest;
    final style = Theme.of(context).textTheme;
    final muted = style.bodySmall?.copyWith(color: PlateColors.muted);
    return Surface(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Daily calorie estimate'),
            style: style.bodyMedium?.copyWith(color: PlateColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  context.number(remaining?.abs() ?? consumed),
                  style: style.displaySmall?.copyWith(color: accent),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  target == null
                      ? context.tr('kcal logged')
                      : aboveTarget
                      ? context.tr('kcal above target')
                      : context.tr('kcal remaining'),
                  style: style.bodyMedium,
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 18),
            Semantics(
              label: context.tr('{p0} percent of target logged', {
                'p0': (progress * 100).round(),
              }),
              excludeSemantics: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress.clamp(0, 1).toDouble()),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    color: accent,
                    backgroundColor: PlateColors.line,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            target == null
                ? context.tr('Set a target in Settings')
                : context.tr('{p0} logged · {p1} target', {
                    'p0': context.number(consumed),
                    'p1': context.number(target),
                  }),
            style: style.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            log.logged
                ? context.tr('Intake range · {p0} kcal', {
                    'p0': log.intake.label,
                  })
                : context.tr(
                    'Estimates appear after your first confirmed meal.',
                  ),
            style: muted,
          ),
          if (target != null && log.logged)
            Text(
              context.tr('Remaining range · {p0} kcal', {
                'p0': log.intake.remaining(target).label,
              }),
              style: muted,
            ),
        ],
      ),
    );
  }
}
