import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/domain/domain.dart';
import '../../../core/format/number_format.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/routes.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'water_amount_dialog.dart';
import 'water_controller.dart';
import 'water_quick_add.dart';

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
        title: 'Remove water entry?',
        message: 'Your hydration total will update.',
        action: 'Remove entry',
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
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Standalone(
    title: 'Water',
    body: ref
        .watch(overviewProvider)
        .when(
          loading: () => const PageScroll(
            children: [LoadingState('Loading your water log…')],
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
              const PageHeading(
                'Water log',
                detail: 'Review what you’ve recorded today.',
              ),
              const SizedBox(height: 12),
              WaterQuickAdd(
                overview.today,
                overview.profile?.waterGoal ?? 2000,
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                'Edit daily water goal',
                onPressed: () => context.push(Routes.profile),
              ),
              const SizedBox(height: 15),
              const SectionTitle('Entries today'),
              const SizedBox(height: 8),
              if (overview.today.water.isEmpty)
                const EmptyState(
                  'No water logged yet',
                  'Use a preset or add a custom amount.',
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
                      title: Text('${number(entry.amount)} ml'),
                      subtitle: Text(
                        DateFormat.jm().format(
                          localTime(entry.at, overview.zone),
                        ),
                      ),
                      trailing: PopupMenuButton<bool>(
                        tooltip: 'Water entry actions',
                        onSelected: (delete) =>
                            update(context, ref, entry, delete: delete),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: false,
                            child: Text('Edit amount'),
                          ),
                          PopupMenuItem(
                            value: true,
                            child: Text('Remove entry'),
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
