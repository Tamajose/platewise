import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/domain/day_log.dart';
import '../../../core/presentation/routes.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'water_amount_dialog.dart';
import 'water_controller.dart';
import '../../../core/l10n/l10n.dart';

/// Today's water against the goal, with buttons to add some. [compact] hides
/// the custom amount and links to the full water log instead.
class WaterQuickAdd extends ConsumerWidget {
  const WaterQuickAdd(this.day, this.goal, {super.key, this.compact = false});

  final DayLog day;
  final int goal;
  final bool compact;

  Future<void> add(BuildContext context, WidgetRef ref, int amount) async {
    final controller = ref.read(waterControllerProvider.notifier);
    final id = await controller.add(amount);
    if (id == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.tr('Added {p0} ml', {'p0': amount})),
          // A snack bar with an action stays until dismissed unless told
          // otherwise, and it would keep covering the buttons beneath it.
          persist: false,
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: context.tr('Undo'),
            textColor: PlateColors.lime,
            onPressed: () async {
              final error = await controller.remove(id);
              if (error != null && context.mounted) {
                messenger.showSnackBar(
                  SnackBar(content: Text(context.tr(error))),
                );
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(waterControllerProvider);
    final amount = day.waterMl;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconTile(
                Icons.water_drop_outlined,
                color: PlateColors.water,
                ink: PlateColors.blue,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Hydration'),
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: PlateColors.blue),
                    ),
                    Text(
                      context.tr('{p0} / {p1} ml', {
                        'p0': context.number(amount),
                        'p1': context.number(goal),
                      }),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: PlateColors.blue),
                    ),
                  ],
                ),
              ),
              if (compact)
                IconButton(
                  onPressed: () => context.push(Routes.water),
                  tooltip: context.tr('Open water log'),
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    color: PlateColors.blue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (amount / goal).clamp(0, 1).toDouble(),
              minHeight: 7,
              semanticsLabel: context.tr('{p0} of {p1} milliliters logged', {
                'p0': amount,
                'p1': goal,
              }),
              color: PlateColors.blue,
              backgroundColor: PlateColors.line,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 5,
            children: [
              for (final preset in [250, 500])
                SecondaryButton(
                  context.tr('+{p0} ml', {'p0': preset}),
                  onPressed: state.busy
                      ? null
                      : () => add(context, ref, preset),
                ),
              if (!compact)
                SecondaryButton(
                  context.tr('Custom'),
                  icon: Icons.add,
                  onPressed: state.busy
                      ? null
                      : () async {
                          final value = await askWaterAmount(context);
                          if (value != null && context.mounted) {
                            await add(context, ref, value);
                          }
                        },
                ),
            ],
          ),
          if (state.busy) LoadingState(context.tr('Saving water…')),
          if (state.error != null) ...[
            const SizedBox(height: 8),
            ErrorState(
              state.error!,
              retry: state.failedAmount == null
                  ? null
                  : () => add(context, ref, state.failedAmount!),
            ),
          ],
        ],
      ),
    );
  }
}
