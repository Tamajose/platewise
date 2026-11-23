import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/domain/profile.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/profile_rules.dart';
import 'profile_actions.dart';

/// Units, body measurements, local day, optional target and water goal. Used to
/// set up a new profile and to edit an existing one.
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key, this.initial, required this.onSaved});

  /// The profile being edited, or null when setting one up.
  final Profile? initial;

  /// Called after the profile was saved.
  final VoidCallback onSaved;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController height, weight, target, zone, water;
  late String units, language;
  bool applies = false, busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    units = p?.units ?? 'metric';
    language = p?.language ?? 'en';
    height = TextEditingController(text: p?.displayHeight.toStringAsFixed(1));
    weight = TextEditingController(text: p?.displayWeight.toStringAsFixed(1));
    target = TextEditingController(text: p?.target?.toString());
    zone = TextEditingController(text: p?.zone ?? 'Asia/Dhaka');
    water = TextEditingController(text: (p?.waterGoal ?? 2000).toString());
    applies = p?.target != null;
  }

  @override
  void dispose() {
    height.dispose();
    weight.dispose();
    target.dispose();
    zone.dispose();
    water.dispose();
    super.dispose();
  }

  void changeUnits(String next) {
    if (units == next) return;
    setState(() {
      height.text = convertHeight(height.text, units, next);
      weight.text = convertWeight(weight.text, units, next);
      units = next;
    });
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final message = await ref
        .read(profileActionsProvider)
        .save(
          ProfileInput(
            units: units,
            height: height.text,
            weight: weight.text,
            target: target.text,
            zone: zone.text,
            language: language,
            waterGoal: water.text,
            targetConfirmed: applies,
            correctionConsent: widget.initial?.correctionConsent ?? false,
          ),
        );
    if (!mounted) return;
    setState(() {
      busy = false;
      error = message;
    });
    if (message == null) widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final index = bmi(height.text, weight.text, units);
    return Form(
      key: formKey,
      child: PageScroll(
        children: [
          PageHeading(
            widget.initial == null
                ? 'Set up your profile'
                : 'Edit your profile',
            detail: 'Choose the units and local day for your log. You can add a daily target if it suits you.',
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: units,
            decoration: const InputDecoration(labelText: 'Measurement units'),
            items: const [
              DropdownMenuItem(
                value: 'metric',
                child: Text('Metric · cm / kg'),
              ),
              DropdownMenuItem(value: 'us', child: Text('US · in / lb')),
            ],
            onChanged: busy ? null : (v) => changeUnits(v!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: height,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: units == 'us' ? 'Height (in)' : 'Height (cm)',
            ),
            validator: (v) => heightError(v ?? '', units),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: weight,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: units == 'us' ? 'Weight (lb)' : 'Weight (kg)',
            ),
            validator: (v) => weightError(v ?? '', units),
          ),
          if (index != null) ...[
            const SizedBox(height: 12),
            Surface(
              color: PlateColors.sage,
              child: Text(
                'BMI ${index.toStringAsFixed(1)} · BMI is a screening measure and does not determine calorie needs.',
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: zone,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'IANA timezone',
              hintText: 'Asia/Dhaka',
              counterText: '',
            ),
            validator: (v) => timezoneError(v ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: target,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Daily target (kcal, optional)',
              errorMaxLines: 5,
            ),
            validator: (v) => targetFieldError(v ?? ''),
          ),
          const SizedBox(height: 8),
          const Text(
            'If you’re under 18, pregnant or breastfeeding, have eating-disorder concerns, or need an individualized nutrition plan, continue without a target and ask a qualified professional.',
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: applies,
            onChanged: busy
                ? null
                : (v) => setState(() => applies = v ?? false),
            title: const Text('Adult target-setting is appropriate for me.'),
          ),
          if (widget.initial != null) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: water,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Water goal (ml)'),
              validator: (v) => waterGoalError(v ?? ''),
            ),
          ],
          const SizedBox(height: 14),
          if (ref.watch(capabilitiesProvider).value?.banglaText == true) ...[
            DropdownButtonFormField<String>(
              initialValue: language,
              decoration: const InputDecoration(
                labelText: 'Preferred analysis language',
              ),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'bn', child: Text('Bangla')),
              ],
              onChanged: busy ? null : (v) => setState(() => language = v!),
            ),
            const SizedBox(height: 8),
          ],
          const DisclaimerNotice(),
          const SizedBox(height: 16),
          if (error != null) ...[
            ErrorState(error!),
            const SizedBox(height: 10),
          ],
          PrimaryButton(
            widget.initial == null ? 'Continue to Today' : 'Save profile',
            onPressed: save,
            busy: busy,
          ),
        ],
      ),
    );
  }
}
