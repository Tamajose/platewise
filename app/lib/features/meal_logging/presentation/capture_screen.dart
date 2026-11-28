import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/domain/photo_picker.dart';
import '../../../core/presentation/review_args.dart';
import '../../../core/presentation/routes.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import 'capture_controller.dart';
import 'voice_input.dart';
import '../../../core/l10n/l10n.dart';

/// Where a meal starts: a photo, a typed description or a voice note.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final description = TextEditingController();

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  CaptureController get controller =>
      ref.read(captureControllerProvider.notifier);

  Future<void> openReview(ReviewArgs args) async {
    final saved = await context.push<bool>(Routes.review, extra: args);
    if (saved == true && mounted) context.pop();
  }

  Future<void> estimate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final isPhoto = ref.read(captureControllerProvider).isPhoto;
    final photo = ref.read(captureControllerProvider).photo;
    final draft = await controller.estimate();
    if (draft == null || !mounted) return;
    await openReview(ReviewArgs(draft, photo: isPhoto ? photo : null));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(captureControllerProvider.select((s) => s.description), (
      _,
      next,
    ) {
      if (description.text != next) description.text = next;
    });
    final state = ref.watch(captureControllerProvider);
    final demo = ref.watch(sessionRepositoryProvider).isDemo;
    final capabilities = ref.watch(capabilitiesProvider).value;
    return Standalone(
      title: context.tr('Log meal'),
      body: PageScroll(
        children: [
          PageHeading(
            context.tr('What did you eat?'),
            detail: context.tr(
              'Review the foods and portions before adding a meal to your log.',
            ),
          ),
          const SizedBox(height: 17),
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: [
              for (final option in [
                (CaptureMethod.photo, 'Photo', Icons.photo_camera_outlined),
                (CaptureMethod.text, 'Text', Icons.edit_outlined),
                (CaptureMethod.voice, 'Voice', Icons.mic_none_rounded),
              ])
                ChoiceChip(
                  label: Text(context.tr(option.$2)),
                  avatar: Icon(option.$3, size: 18),
                  selected: state.method == option.$1,
                  onSelected: state.busy
                      ? null
                      : (_) => controller.selectMethod(option.$1),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.isPhoto) ...[
            if (state.photo != null)
              FoodPicture(bytes: state.photo)
            else
              Surface(
                color: PlateColors.sage,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Column(
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: PlateColors.forest,
                        size: 30,
                      ),
                      SizedBox(height: 8),
                      Text(context.tr('Add a photo of your meal')),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 11),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SecondaryButton(
                  state.photo == null
                      ? context.tr('Camera')
                      : context.tr('Retake'),
                  icon: Icons.photo_camera_outlined,
                  onPressed: state.busy
                      ? null
                      : () => controller.pickPhoto(PhotoSource.camera),
                ),
                SecondaryButton(
                  state.photo == null
                      ? context.tr('Gallery')
                      : context.tr('Replace'),
                  icon: Icons.photo_library_outlined,
                  onPressed: state.busy
                      ? null
                      : () => controller.pickPhoto(PhotoSource.gallery),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              context.tr(
                'Keep people and personal information out of the photo.',
              ),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: PlateColors.muted),
            ),
            if (demo) ...[
              const SizedBox(height: 12),
              SecondaryButton(
                context.tr('Review sample photo estimate'),
                onPressed: state.busy
                    ? null
                    : () => openReview(controller.sampleReview()!),
              ),
            ],
          ] else if (state.method == CaptureMethod.voice)
            VoiceInput(
              transcript: description,
              useTyped: () => controller.selectMethod(CaptureMethod.text),
            )
          else ...[
            TextField(
              controller: description,
              enabled: !state.busy,
              onChanged: controller.setDescription,
              minLines: 3,
              maxLines: 6,
              maxLength: maxDescriptionLength,
              buildCounter: context.counterBuilder,
              decoration: InputDecoration(
                labelText: context.tr('Describe the meal'),
                alignLabelWithHint: true,
                hintText: context.tr(
                  'Example: 1 cup of rice and 1 bowl of dal',
                ),
              ),
            ),
            if (capabilities?.banglaText ?? false)
              DropdownButtonFormField<String>(
                key: ValueKey(state.language),
                initialValue: state.language,
                decoration: InputDecoration(
                  labelText: context.tr('Input language'),
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
                onChanged: state.busy
                    ? null
                    : (value) => controller.setLanguage(value!),
              ),
            if (demo)
              DisclaimerNotice(
                text: context.tr(
                  'Demo lookup supports a few sample dishes including rice, dal, khichuri and chicken tikka.',
                ),
              ),
          ],
          const SizedBox(height: 16),
          if (state.busy)
            LoadingState(context.tr('Preparing your meal estimate…')),
          if (state.error != null) ...[
            ErrorState(state.error!),
            const SizedBox(height: 9),
          ],
          PrimaryButton(
            context.tr('Estimate meal'),
            icon: Icons.auto_awesome_outlined,
            busy: state.busy,
            onPressed: state.canEstimate ? estimate : null,
          ),
          const SizedBox(height: 9),
          SecondaryButton(
            context.tr('Enter meal manually'),
            icon: Icons.edit_note,
            onPressed: state.busy
                ? null
                : () => openReview(controller.manualReview()),
          ),
          const SizedBox(height: 14),
          const DisclaimerNotice(),
        ],
      ),
    );
  }
}
