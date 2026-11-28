import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/presentation/routes.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/decision.dart';
import 'decision_results.dart';
import 'menu_dish_dialog.dart';
import 'menu_review_args.dart';
import 'menu_review_controller.dart';
import 'small_budget_note.dart';
import '../../../core/l10n/l10n.dart';

/// Check the dishes found on a menu, fix names and portions, pick two or
/// three, and compare them.
class MenuReviewScreen extends ConsumerWidget {
  const MenuReviewScreen(this.args, {super.key});
  final MenuReviewArgs args;

  Future<void> edit(
    BuildContext context,
    WidgetRef ref,
    MenuOption dish,
    int? index,
  ) async {
    final next = await showDialog<MenuOption>(
      context: context,
      builder: (_) => MenuDishDialog(dish),
    );
    if (next == null || !context.mounted) return;
    final controller = ref.read(menuReviewControllerProvider(args).notifier);
    index == null
        ? controller.addDish(next)
        : controller.replaceDish(index, next);
  }

  Future<void> choose(
    BuildContext context,
    WidgetRef ref,
    RankedMeal meal,
  ) async {
    final saved = await context.push<bool>(
      Routes.review,
      extra: ref
          .read(menuReviewControllerProvider(args).notifier)
          .reviewFor(meal),
    );
    if (saved == true && context.mounted) context.go(Routes.today);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(menuReviewControllerProvider(args));
    final controller = ref.read(menuReviewControllerProvider(args).notifier);
    return Standalone(
      title: context.tr('Review menu'),
      body: PageScroll(
        maxWidth: 880,
        children: [
          PageHeading(
            context.tr('Check menu options'),
            detail: args.sample
                ? context.tr(
                    'Sample menu. Edit any dish, then compare two or three options.',
                  )
                : context.tr(
                    'Correct names and portions. Leave calories blank when the menu gives only a price.',
                  ),
          ),
          SmallBudgetNote(args.budget),
          const SizedBox(height: 12),
          if (args.photo != null) ...[
            FoodPicture(bytes: args.photo),
            const SizedBox(height: 12),
          ],
          for (var i = 0; i < state.options.length; i++) ...[
            Surface(
              padding: const EdgeInsets.fromLTRB(2, 4, 4, 4),
              child: Row(
                children: [
                  Checkbox(
                    value: state.selected.contains(i),
                    semanticLabel: context.tr('Select menu dish {p0}', {
                      'p0': i + 1,
                    }),
                    onChanged: state.busy
                        ? null
                        : (value) => controller.select(i, value ?? false),
                  ),
                  Expanded(
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          state.options[i].name.isEmpty
                              ? context.tr('Enter dish {p0}', {'p0': i + 1})
                              : state.options[i].name,
                        ),
                        subtitle: Text(
                          context.tr('{p0} · {p1}', {
                            'p0':
                                state.options[i].portion ??
                                context.tr('Portion unlisted'),
                            'p1': state.options[i].kcal == null
                                ? context.tr('Inference needed')
                                : context.tr('{p0} kcal entered', {
                                    'p0': state.options[i].kcal,
                                  }),
                          }),
                        ),
                        onTap: state.busy
                            ? null
                            : () => edit(context, ref, state.options[i], i),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: state.busy
                        ? null
                        : () => edit(context, ref, state.options[i], i),
                    tooltip: context.tr('Edit dish {p0}', {'p0': i + 1}),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (state.canAddDish)
            TextButton.icon(
              onPressed: state.busy
                  ? null
                  : () => edit(context, ref, const MenuOption(''), null),
              icon: const Icon(Icons.add),
              label: Text(context.tr('Add a dish')),
            ),
          if (state.error != null) ...[
            ErrorState(state.error!),
            const SizedBox(height: 8),
          ],
          PrimaryButton(
            context.tr('Compare selected dishes'),
            onPressed: controller.compare,
            busy: state.busy,
            icon: Icons.compare_arrows_rounded,
          ),
          if (state.busy) LoadingState(context.tr('Preparing menu estimates…')),
          if (state.result != null) ...[
            const SizedBox(height: 15),
            DecisionResults(
              state.result!,
              budget: args.budget,
              choose: (meal) => choose(context, ref, meal),
              onRetry: state.busy ? null : controller.compare,
            ),
          ],
          const SizedBox(height: 14),
          const DisclaimerNotice(),
        ],
      ),
    );
  }
}
