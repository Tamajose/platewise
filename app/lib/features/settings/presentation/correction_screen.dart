import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/widgets.dart';
import '../domain/settings_rules.dart';
import 'settings_controller.dart';

/// Submit a known portion and calorie range for review.
class CorrectionScreen extends ConsumerStatefulWidget {
  const CorrectionScreen({super.key});

  @override
  ConsumerState<CorrectionScreen> createState() => _CorrectionScreenState();
}

class _CorrectionScreenState extends ConsumerState<CorrectionScreen> {
  final form = GlobalKey<FormState>();
  final grams = TextEditingController(),
      low = TextEditingController(),
      high = TextEditingController();
  String food = correctionFoods.first;

  @override
  void dispose() {
    grams.dispose();
    low.dispose();
    high.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final controller = ref.read(correctionControllerProvider.notifier);
    final built = buildCorrection(
      food: food,
      grams: grams.text,
      low: low.text,
      high: high.text,
    );
    if (built.correction == null) {
      controller.fail(built.error!);
      return;
    }
    final sent = await controller.submit(built.correction!);
    if (!sent || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Correction submitted for review')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(correctionControllerProvider);
    return Standalone(
      title: 'Share a correction',
      body: Form(
        key: form,
        child: PageScroll(
          children: [
            const PageHeading(
              'Food correction',
              detail: 'Submit a known portion and calorie range for review. Photos and personal notes stay in your log.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: food,
              decoration: const InputDecoration(labelText: 'Food'),
              items: [
                for (final option in correctionFoods)
                  DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: state.busy
                  ? null
                  : (value) => setState(() => food = value!),
            ),
            const SizedBox(height: 8),
            for (final field in [
              (grams, 'Portion (g)', 1, 3000),
              (low, 'Low estimate (kcal)', 0, 6000),
              (high, 'High estimate (kcal)', 0, 6000),
            ]) ...[
              TextFormField(
                controller: field.$1,
                decoration: InputDecoration(labelText: field.$2),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  return n == null || n < field.$3 || n > field.$4
                      ? 'Enter ${field.$3}–${field.$4}.'
                      : null;
                },
              ),
              const SizedBox(height: 8),
            ],
            if (state.error != null) ...[
              ErrorState(state.error!),
              const SizedBox(height: 8),
            ],
            PrimaryButton(
              'Submit for review',
              onPressed: submit,
              busy: state.busy,
            ),
          ],
        ),
      ),
    );
  }
}
