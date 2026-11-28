import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/domain/domain.dart';
import '../../../core/presentation/review_args.dart';
import '../../../core/presentation/routes.dart';
import '../../../core/widgets/widgets.dart';
import 'today_controller.dart';
import '../../../core/l10n/l10n.dart';

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
      title: context.tr('Delete this meal?'),
      message: context.tr('This removes the meal and any photo saved with it.'),
      action: context.tr('Delete meal'),
      danger: true,
    );
    if (!yes || !context.mounted) return;
    final error = await ref.read(todayActionsProvider).deleteMeal(meal.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr(error ?? 'Meal deleted'))),
    );
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
        context.tr(meal.draft.title),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        context.tr('{p0} · {p1} kcal', {
          'p0': context.timeFormat.format(localTime(meal.at, zone)),
          'p1': meal.range.label,
        }),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: context.tr('Actions for {p0}', {
          'p0': context.tr(meal.draft.title),
        }),
        onSelected: (value) =>
            value == 'edit' ? edit(context) : delete(context, ref),
        itemBuilder: (_) => [
          PopupMenuItem(value: 'edit', child: Text(context.tr('Edit meal'))),
          PopupMenuItem(
            value: 'delete',
            child: Text(context.tr('Delete meal')),
          ),
        ],
      ),
    ),
  );
}
