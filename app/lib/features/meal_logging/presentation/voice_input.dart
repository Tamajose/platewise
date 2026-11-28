import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/voice.dart';
import 'capture_controller.dart';
import 'voice_controller.dart';
import '../../../core/l10n/l10n.dart';

/// The voice tab: record a note, or type or edit the transcript.
class VoiceInput extends ConsumerWidget {
  const VoiceInput({
    super.key,
    required this.transcript,
    required this.useTyped,
  });

  /// Holds the transcript text and lets the person correct it.
  final TextEditingController transcript;

  /// Switches the screen to typed entry.
  final VoidCallback useTyped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceControllerProvider);
    final controller = ref.read(voiceControllerProvider.notifier);
    final demo = ref.watch(sessionRepositoryProvider).isDemo;
    final caps = ref.watch(capabilitiesProvider).value;
    final allowLive = caps?.liveAi == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (caps?.banglaSpeech == true) ...[
          DropdownButtonFormField<String>(
            initialValue: voice.locale,
            decoration: InputDecoration(
              labelText: context.tr('Recording language'),
            ),
            items: [
              DropdownMenuItem(value: 'en', child: Text(context.tr('English'))),
              DropdownMenuItem(value: 'bn', child: Text(context.tr('Bangla'))),
            ],
            onChanged: voice.listening || voice.busy
                ? null
                : (value) => controller.setLocale(value!),
          ),
          const SizedBox(height: 8),
        ] else
          Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              context.tr(
                'Bangla speech is unavailable here. You can type food names in manual entry.',
              ),
            ),
          ),
        if (allowLive)
          SecondaryButton(
            voice.listening
                ? context.tr('Stop and transcribe')
                : context.tr('Record voice note'),
            onPressed: voice.busy
                ? null
                : voice.listening
                ? controller.stop
                : controller.start,
            icon: voice.listening
                ? Icons.stop_circle_outlined
                : Icons.mic_none_rounded,
          )
        else if (demo)
          SecondaryButton(
            context.tr('Use sample transcript'),
            icon: Icons.mic_none_rounded,
            onPressed: () => ref
                .read(captureControllerProvider.notifier)
                .useTranscript('One cup of rice and a bowl of dal', 'en'),
          )
        else
          Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              context.tr(
                'Live transcription is unavailable. Type the description to continue.',
              ),
            ),
          ),
        if (voice.listening)
          Padding(
            padding: EdgeInsets.only(top: 7),
            child: Text(
              context.tr(
                'Recording · stops after {p0} seconds. Say only the foods and portions.',
                {'p0': maxVoiceSeconds},
              ),
            ),
          ),
        if (voice.busy) LoadingState(context.tr('Preparing voice entry…')),
        if (voice.error != null) ...[
          const SizedBox(height: 8),
          ErrorState(voice.error!),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: transcript,
          onChanged: ref
              .read(captureControllerProvider.notifier)
              .setDescription,
          minLines: 3,
          maxLines: 6,
          maxLength: maxDescriptionLength,
          buildCounter: context.counterBuilder,
          enabled: !voice.listening && !voice.busy,
          decoration: InputDecoration(
            labelText: context.tr('Review or type transcript'),
            alignLabelWithHint: true,
          ),
        ),
        TextButton(
          onPressed: voice.listening || voice.busy ? null : useTyped,
          child: Text(context.tr('Switch to typed entry')),
        ),
      ],
    );
  }
}
