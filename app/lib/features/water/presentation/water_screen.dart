import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/domain/domain.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/routes.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'water_amount_dialog.dart';
import 'water_controller.dart';
import 'water_quick_add.dart';
import '../../../core/l10n/l10n.dart';

/// Today's water entries, with a way to add, change and remove them.
class WaterScreen extends ConsumerWidget {
  const WaterScreen({super.key});

  Future<void> update(
    BuildContext context,
    WidgetRef ref,
    WaterEntry entry, {
    required bool delete,
  }) async {
    final controller = ref.read(waterControllerProvider.notifier);
    final String? error;
    if (delete) {
      final yes = await ConfirmationSheet.ask(
        context,
        title: context.tr('Remove water entry?'),
        message: context.tr('Your hydration total will update.'),
        action: context.tr('Remove entry'),
        danger: true,
      );
      if (!yes || !context.mounted) return;
      error = await controller.remove(entry.id);
    } else {
      final next = await askWaterAmount(context, initial: entry.amount);
      if (next == null || !context.mounted) return;
      error = await controller.edit(entry, next);
    }
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Standalone(
    title: context.tr('Water'),
    body: ref
        .watch(overviewProvider)
        .when(
          loading: () => PageScroll(
            children: [LoadingState(context.tr('Loading your water log…'))],
          ),
          error: (e, _) => PageScroll(
            children: [
              ErrorState(
                failureMessage(e),
                retry: () => ref.invalidate(overviewProvider),
              ),
            ],
          ),
          data: (overview) => PageScroll(
            children: [
              PageHeading(
                context.tr('Water log'),
                detail: context.tr('Review what you’ve recorded today.'),
              ),
              const SizedBox(height: 12),
              WaterQuickAdd(
                overview.today,
                overview.profile?.waterGoal ?? 2000,
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                context.tr('Edit daily water goal'),
                onPressed: () => context.push(Routes.profile),
              ),
              const SizedBox(height: 15),
              SectionTitle(context.tr('Entries today')),
              const SizedBox(height: 8),
              if (overview.today.water.isEmpty)
                EmptyState(
                  context.tr('No water logged yet'),
                  context.tr('Use a preset or add a custom amount.'),
                  icon: Icons.water_drop_outlined,
                ),
              for (final entry in overview.today.water.reversed) ...[
                Surface(
                  padding: const EdgeInsets.fromLTRB(11, 1, 3, 1),
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const IconTile(
                        Icons.water_drop_outlined,
                        color: PlateColors.water,
                        ink: PlateColors.blue,
                      ),
                      title: Text(
                        context.tr('{p0} ml', {
                          'p0': context.number(entry.amount),
                        }),
                      ),
                      subtitle: Text(
                        context.timeFormat.format(
                          localTime(entry.at, overview.zone),
                        ),
                      ),
                      trailing: PopupMenuButton<bool>(
                        tooltip: context.tr('Water entry actions'),
                        onSelected: (delete) =>
                            update(context, ref, entry, delete: delete),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: false,
                            child: Text(context.tr('Edit amount')),
                          ),
                          PopupMenuItem(
                            value: true,
                            child: Text(context.tr('Remove entry')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
              ],
            ],
          ),
        ),
  );
}
