import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/widgets.dart';
import '../domain/water_repository.dart';

/// Asks for an amount in millilitres. Null when cancelled.
Future<int?> askWaterAmount(BuildContext context, {int? initial}) =>
    showDialog<int>(
      context: context,
      builder: (_) => _WaterAmountDialog(initial),
    );

class _WaterAmountDialog extends StatefulWidget {
  const _WaterAmountDialog(this.initial);
  final int? initial;

  @override
  State<_WaterAmountDialog> createState() => _WaterAmountDialogState();
}

class _WaterAmountDialogState extends State<_WaterAmountDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initial?.toString());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    if (form.currentState!.validate()) {
      Navigator.pop(context, parseWaterAmount(controller.text));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Add water' : 'Edit water'),
    scrollable: true,
    content: Form(
      key: form,
      child: TextFormField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        onFieldSubmitted: (_) => submit(),
        decoration: const InputDecoration(labelText: 'Amount (ml)'),
        validator: (value) =>
            parseWaterAmount(value ?? '') == null ? waterAmountMessage : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      PrimaryButton('Save water', onPressed: submit),
    ],
  );
}
