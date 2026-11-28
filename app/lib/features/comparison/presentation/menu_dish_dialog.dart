import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/widgets.dart';
import '../domain/compare_photos.dart';
import '../domain/decision.dart';
import '../../../core/l10n/l10n.dart';

/// A dialog for adding or correcting one menu dish. Pops with the new
/// [MenuOption].
class MenuDishDialog extends StatefulWidget {
  const MenuDishDialog(this.initial, {super.key});
  final MenuOption initial;

  @override
  State<MenuDishDialog> createState() => _MenuDishDialogState();
}

class _MenuDishDialogState extends State<MenuDishDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, portion, kcal;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.initial.name);
    portion = TextEditingController(text: widget.initial.portion);
    kcal = TextEditingController(text: widget.initial.kcal?.toString());
  }

  @override
  void dispose() {
    name.dispose();
    portion.dispose();
    kcal.dispose();
    super.dispose();
  }

  /// Only the calorie field's own problem, whatever the name field holds.
  String? _check(String? _) =>
      buildMenuOption(name: 'dish', portion: '', kcal: kcal.text).error;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr('Edit dish')),
    scrollable: true,
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: name,
            maxLength: 100,
            buildCounter: context.counterBuilder,
            decoration: InputDecoration(
              labelText: context.tr('Dish name'),
              counterText: '',
            ),
            validator: (v) =>
                v!.trim().isEmpty ? context.tr('Enter a dish name.') : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: portion,
            maxLength: 100,
            buildCounter: context.counterBuilder,
            decoration: InputDecoration(
              labelText: context.tr('Portion (optional)'),
              counterText: '',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: kcal,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('Printed kcal (optional)'),
            ),
            validator: (v) => v!.trim().isEmpty ? null : _check(v),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr('Cancel')),
      ),
      PrimaryButton(
        context.tr('Apply'),
        onPressed: () {
          if (!form.currentState!.validate()) return;
          Navigator.pop(
            context,
            buildMenuOption(
              name: name.text,
              portion: portion.text,
              kcal: kcal.text,
            ).dish,
          );
        },
      ),
    ],
  );
}
