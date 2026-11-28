import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/domain/domain.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/energy.dart';
import 'settings_controller.dart';
import '../../../core/l10n/l10n.dart';

/// Estimate adult energy needs and, if the person chooses, use the result as
/// the daily target.
class EnergyScreen extends ConsumerWidget {
  const EnergyScreen({super.key});

  Future<void> apply(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
    int total,
  ) async {
    final yes = await ConfirmationSheet.ask(
      context,
      title: context.tr('Use this estimate as your target?'),
      message: context.tr(
        'Your daily target will be {p0} kcal starting today. Previous dates keep their saved targets.',
        {'p0': context.number(total)},
      ),
      action: context.tr('Confirm target'),
    );
    if (!yes || !context.mounted) return;
    final saved = await ref
        .read(energyControllerProvider.notifier)
        .applyAsTarget(profile, total);
    if (!saved || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr('Daily target updated'))));
    context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(overviewProvider).value?.profile;
    final state = ref.watch(energyControllerProvider);
    final controller = ref.read(energyControllerProvider.notifier);
    final inputsOn = state.eligible && !state.busy;
    return Standalone(
      title: context.tr('Energy estimate'),
      body: PageScroll(
        children: [
          PageHeading(
            context.tr('Estimate adult energy needs'),
            detail: context.tr(
              'Use your profile height and weight with the Mifflin–St Jeor equation. You decide whether to use the result.',
            ),
          ),
          const SizedBox(height: 12),
          Surface(
            color: PlateColors.sage,
            child: Text(
              context.tr(
                'This pilot supports ages 19 to 78. Skip this estimate during pregnancy or breastfeeding, with eating-disorder concerns, or when you need an individualized nutrition plan. You can keep logging meals and speak with a qualified professional.',
              ),
            ),
          ),
          CheckboxListTile(
            value: state.eligible,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(context.tr('The adult estimate applies to me.')),
            onChanged: state.busy
                ? null
                : (value) => controller.setEligible(value ?? false),
          ),
          const SizedBox(height: 8),
          TextField(
            enabled: inputsOn,
            keyboardType: TextInputType.number,
            onChanged: controller.setAge,
            decoration: InputDecoration(labelText: context.tr('Age in years')),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: state.coefficient,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('Calculation group'),
            ),
            items: [
              DropdownMenuItem(
                value: 'plus_5',
                child: Text(context.tr('Male study group (+5)')),
              ),
              DropdownMenuItem(
                value: 'minus_161',
                child: Text(context.tr('Female study group (−161)')),
              ),
            ],
            onChanged: inputsOn ? controller.setCoefficient : null,
          ),
          const SizedBox(height: 5),
          Text(
            context.tr(
              'The original study used two group constants. Choose the relevant one or skip the estimate.',
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: state.activity,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('Typical activity'),
            ),
            items: [
              DropdownMenuItem(
                value: 'low',
                child: Text(context.tr('Mostly seated')),
              ),
              DropdownMenuItem(
                value: 'some',
                child: Text(context.tr('Some daily movement')),
              ),
              DropdownMenuItem(
                value: 'regular',
                child: Text(context.tr('Regular moderate activity')),
              ),
            ],
            onChanged: inputsOn ? controller.setActivity : null,
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            context.tr('Calculate estimate'),
            onPressed: profile != null && state.eligible
                ? () => controller.calculate(profile)
                : null,
            busy: state.busy,
          ),
          if (state.result case final EnergyEstimate estimated) ...[
            const SizedBox(height: 13),
            MetricCard(
              label: context.tr('Estimated daily energy use'),
              value: context.tr('{p0} kcal', {
                'p0': context.number(estimated.total),
              }),
              detail: context.tr(
                'Estimated resting energy {p0} kcal × activity {p1}. Activity multipliers are approximations.',
                {
                  'p0': context.number(estimated.resting),
                  'p1': estimated.multiplier,
                },
              ),
            ),
            const SizedBox(height: 8),
            if (estimated.canApply && profile != null)
              SecondaryButton(
                context.tr('Review as a daily target'),
                onPressed: state.busy
                    ? null
                    : () => apply(context, ref, profile, estimated.total),
              )
            else
              const ErrorState(targetGuidance),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 8),
            ErrorState(state.error!),
          ],
          const SizedBox(height: 12),
          DisclaimerNotice(
            text: context.tr(
              'An estimate of daily energy use is approximate. PlateWise does not prescribe a deficit or provide medical advice.',
            ),
          ),
        ],
      ),
    );
  }
}
