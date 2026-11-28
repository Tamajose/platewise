import 'package:material_ui/material_ui.dart';

import '../../../core/domain/domain.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/food_entry.dart';
import '../../../core/l10n/l10n.dart';

/// A bottom sheet for adding a food or changing a food's portion. Pops with
/// the new [FoodItem].
class FoodEstimateEditor extends StatefulWidget {
  const FoodEstimateEditor({super.key, this.initial});

  /// The food being edited, or null to add a new one.
  final FoodItem? initial;

  @override
  State<FoodEstimateEditor> createState() => _FoodEstimateEditorState();
}

class _FoodEstimateEditorState extends State<FoodEstimateEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, amount, low, high;
  late String unit;
  bool customRange = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final food = widget.initial;
    name = TextEditingController(text: food?.name);
    amount = TextEditingController(text: food?.quantity.toString() ?? '1');
    low = TextEditingController(text: food?.range.low.toString());
    high = TextEditingController(text: food?.range.high.toString());
    unit = food?.unit ?? 'serving';
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    low.dispose();
    high.dispose();
    super.dispose();
  }

  bool get replaced => isReplacementFood(widget.initial, name.text, unit);

  /// A new quantity of the same food rescales its range, until the person
  /// types a range of their own.
  void updatePortion() {
    final quantity = parseQuantity(amount.text);
    if (!replaced && !customRange && quantity != null) {
      final scaled = widget.initial!.scale(quantity);
      low.text = scaled.range.low.toString();
      high.text = scaled.range.high.toString();
    }
    setState(() {});
  }

  /// A different food or unit has no known range, so the old one is cleared.
  void clearForReplacement() {
    if (widget.initial != null && replaced && !customRange) {
      low.clear();
      high.clear();
      setState(() {});
    } else {
      updatePortion();
    }
  }

  void submit() {
    if (!form.currentState!.validate()) return;
    final result = buildFood(
      initial: widget.initial,
      name: name.text,
      quantity: amount.text,
      unit: unit,
      low: low.text,
      high: high.text,
      customRange: customRange,
    );
    if (result.item == null) {
      setState(() => error = result.error);
      return;
    }
    Navigator.pop(context, result.item);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: AnimatedPadding(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 130),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.initial == null
                    ? context.tr('Add food')
                    : context.tr('Edit food and portion'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 11),
              TextFormField(
                controller: name,
                maxLength: 100,
                buildCounter: context.counterBuilder,
                onChanged: (_) => clearForReplacement(),
                decoration: InputDecoration(
                  labelText: context.tr('Food name'),
                  counterText: '',
                ),
                validator: (v) =>
                    v!.trim().isEmpty ? context.tr('Enter a food name.') : null,
              ),
              const SizedBox(height: 11),
              TextFormField(
                controller: amount,
                onChanged: (_) => updatePortion(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: context.tr('Quantity')),
                validator: (v) =>
                    parseQuantity(v ?? '') == null ? quantityMessage : null,
              ),
              const SizedBox(height: 11),
              DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: InputDecoration(
                  labelText: context.tr('Portion unit'),
                ),
                items: [
                  for (final value in foodUnits)
                    DropdownMenuItem(value: value, child: Text(value)),
                ],
                onChanged: (value) {
                  unit = value!;
                  clearForReplacement();
                },
              ),
              const SizedBox(height: 11),
              for (final entry in [
                (low, 'Low estimate (kcal)'),
                (high, 'High estimate (kcal)'),
              ]) ...[
                TextFormField(
                  controller: entry.$1,
                  onChanged: (_) => customRange = true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.tr(entry.$2)),
                  validator: (v) =>
                      parseCalories(v ?? '') == null ? caloriesMessage : null,
                ),
                const SizedBox(height: 11),
              ],
              if (error != null) ...[
                ErrorState(error!),
                const SizedBox(height: 8),
              ],
              if (replaced && widget.initial != null)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    context.tr(
                      'Enter a new range for this food or unit. Nutrients will be shown as unavailable.',
                    ),
                  ),
                ),
              PrimaryButton(
                context.tr('Apply food changes'),
                onPressed: submit,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
