import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/domain/domain.dart';
import '../../../core/presentation/review_args.dart';
import '../../../core/presentation/routes.dart';
import '../../../core/widgets/widgets.dart';
import 'today_controller.dart';

/// One logged meal, with actions to edit or delete it.
class MealListItem extends ConsumerWidget {
  const MealListItem(this.meal, this.zone, {super.key});
  final SavedMeal meal;
  final String zone;

  void edit(BuildContext context) =>
      context.push(Routes.review, extra: ReviewArgs(meal.editable));

  Future<void> delete(BuildContext context, WidgetRef ref) async {
    final yes = await ConfirmationSheet.ask(
      context,
      title: 'Delete this meal?',
      message: 'This removes the meal and any photo saved with it.',
      action: 'Delete meal',
      danger: true,
    );
    if (!yes || !context.mounted) return;
    final error = await ref.read(todayActionsProvider).deleteMeal(meal.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? 'Meal deleted')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    type: MaterialType.transparency,
    child: ListTile(
      contentPadding: const EdgeInsets.only(left: 3),
      onTap: () => edit(context),
      leading: IconTile(
        meal.draft.source == MealSource.photo
            ? Icons.photo_camera_outlined
            : Icons.restaurant_outlined,
      ),
      title: Text(
        meal.draft.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        '${DateFormat.jm().format(localTime(meal.at, zone))} · ${meal.range.label} kcal',
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Actions for ${meal.draft.title}',
        onSelected: (value) =>
            value == 'edit' ? edit(context) : delete(context, ref),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit meal')),
          PopupMenuItem(value: 'delete', child: Text('Delete meal')),
        ],
      ),
    ),
  );
}
