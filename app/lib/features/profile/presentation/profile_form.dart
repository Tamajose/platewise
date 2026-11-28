import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/domain/profile.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/profile_rules.dart';
import 'profile_actions.dart';
import '../../../core/l10n/l10n.dart';

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
                ? context.tr('Set up your profile')
                : context.tr('Edit your profile'),
            detail: context.tr(
              'Choose the units and local day for your log. You can add a daily target if it suits you.',
            ),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: units,
            decoration: InputDecoration(
              labelText: context.tr('Measurement units'),
            ),
            items: [
              DropdownMenuItem(
                value: 'metric',
                child: Text(context.tr('Metric · cm / kg')),
              ),
              DropdownMenuItem(
                value: 'us',
                child: Text(context.tr('US · in / lb')),
              ),
            ],
            onChanged: busy ? null : (v) => changeUnits(v!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: height,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: units == 'us'
                  ? context.tr('Height (in)')
                  : context.tr('Height (cm)'),
            ),
            validator: (v) => heightError(v ?? '', units),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: weight,
            onChanged: (_) => setState(() {}),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: units == 'us'
                  ? context.tr('Weight (lb)')
                  : context.tr('Weight (kg)'),
            ),
            validator: (v) => weightError(v ?? '', units),
          ),
          if (index != null) ...[
            const SizedBox(height: 12),
            Surface(
              color: PlateColors.sage,
              child: Text(
                context.tr(
                  'BMI {p0} · BMI is a screening measure and does not determine calorie needs.',
                  {'p0': index.toStringAsFixed(1)},
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: zone,
            maxLength: 80,
            buildCounter: context.counterBuilder,
            decoration: InputDecoration(
              labelText: context.tr('IANA timezone'),
              hintText: context.tr('Asia/Dhaka'),
              counterText: '',
            ),
            validator: (v) => timezoneError(v ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: target,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('Daily target (kcal, optional)'),
              errorMaxLines: 5,
            ),
            validator: (v) => targetFieldError(v ?? ''),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'If you’re under 18, pregnant or breastfeeding, have eating-disorder concerns, or need an individualized nutrition plan, continue without a target and ask a qualified professional.',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: applies,
            onChanged: busy
                ? null
                : (v) => setState(() => applies = v ?? false),
            title: Text(
              context.tr('Adult target-setting is appropriate for me.'),
            ),
          ),
          if (widget.initial != null) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: water,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr('Water goal (ml)'),
              ),
              validator: (v) => waterGoalError(v ?? ''),
            ),
          ],
          const SizedBox(height: 14),
          if (ref.watch(capabilitiesProvider).value?.banglaText == true) ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: language,
              decoration: InputDecoration(
                labelText: context.tr('Preferred analysis language'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'en',
                  child: Text(context.tr('English')),
                ),
                DropdownMenuItem(
                  value: 'bn',
                  child: Text(context.tr('Bangla')),
                ),
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
            widget.initial == null
                ? context.tr('Continue to Today')
                : context.tr('Save profile'),
            onPressed: save,
            busy: busy,
          ),
        ],
      ),
    );
  }
}
