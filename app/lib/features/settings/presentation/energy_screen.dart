import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/domain/domain.dart';
import '../../../core/format/number_format.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/energy.dart';
import 'settings_controller.dart';

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
      title: 'Use this estimate as your target?',
      message:
          'Your daily target will be ${number(total)} kcal starting today. Previous dates keep their saved targets.',
      action: 'Confirm target',
    );
    if (!yes || !context.mounted) return;
    final saved = await ref
        .read(energyControllerProvider.notifier)
        .applyAsTarget(profile, total);
    if (!saved || !context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Daily target updated')));
    context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(overviewProvider).value?.profile;
    final state = ref.watch(energyControllerProvider);
    final controller = ref.read(energyControllerProvider.notifier);
    final inputsOn = state.eligible && !state.busy;
    return Standalone(
      title: 'Energy estimate',
      body: PageScroll(
        children: [
          const PageHeading(
            'Estimate adult energy needs',
            detail: 'Use your profile height and weight with the Mifflin–St Jeor equation. You decide whether to use the result.',
          ),
          const SizedBox(height: 12),
          const Surface(
            color: PlateColors.sage,
            child: Text(
              'This pilot supports ages 19 to 78. Skip this estimate during pregnancy or breastfeeding, with eating-disorder concerns, or when you need an individualized nutrition plan. You can keep logging meals and speak with a qualified professional.',
            ),
          ),
          CheckboxListTile(
            value: state.eligible,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('The adult estimate applies to me.'),
            onChanged: state.busy
                ? null
                : (value) => controller.setEligible(value ?? false),
          ),
          const SizedBox(height: 8),
          TextField(
            enabled: inputsOn,
            keyboardType: TextInputType.number,
            onChanged: controller.setAge,
            decoration: const InputDecoration(labelText: 'Age in years'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: state.coefficient,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Calculation group'),
            items: const [
              DropdownMenuItem(
                value: 'plus_5',
                child: Text('Male study group (+5)'),
              ),
              DropdownMenuItem(
                value: 'minus_161',
                child: Text('Female study group (−161)'),
              ),
            ],
            onChanged: inputsOn ? controller.setCoefficient : null,
          ),
          const SizedBox(height: 5),
          const Text(
            'The original study used two group constants. Choose the relevant one or skip the estimate.',
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: state.activity,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Typical activity'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Mostly seated')),
              DropdownMenuItem(
                value: 'some',
                child: Text('Some daily movement'),
              ),
              DropdownMenuItem(
                value: 'regular',
                child: Text('Regular moderate activity'),
              ),
            ],
            onChanged: inputsOn ? controller.setActivity : null,
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            'Calculate estimate',
            onPressed: profile != null && state.eligible
                ? () => controller.calculate(profile)
                : null,
            busy: state.busy,
          ),
          if (state.result case final EnergyEstimate estimated) ...[
            const SizedBox(height: 13),
            MetricCard(
              label: 'Estimated daily energy use',
              value: '${number(estimated.total)} kcal',
              detail:
                  'Estimated resting energy ${number(estimated.resting)} kcal × activity ${estimated.multiplier}. Activity multipliers are approximations.',
            ),
            const SizedBox(height: 8),
            if (estimated.canApply && profile != null)
              SecondaryButton(
                'Review as a daily target',
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
          const DisclaimerNotice(
            text: 'An estimate of daily energy use is approximate. PlateWise does not prescribe a deficit or provide medical advice.',
          ),
        ],
      ),
    );
  }
}
