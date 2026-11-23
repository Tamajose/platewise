import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/voice.dart';
import 'capture_controller.dart';
import 'voice_controller.dart';

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
            decoration: const InputDecoration(labelText: 'Recording language'),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'bn', child: Text('Bangla')),
            ],
            onChanged: voice.listening || voice.busy
                ? null
                : (value) => controller.setLocale(value!),
          ),
          const SizedBox(height: 8),
        ] else
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Bangla speech is unavailable here. You can type food names in manual entry.',
            ),
          ),
        if (allowLive)
          SecondaryButton(
            voice.listening ? 'Stop and transcribe' : 'Record voice note',
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
            'Use sample transcript',
            icon: Icons.mic_none_rounded,
            onPressed: () => ref
                .read(captureControllerProvider.notifier)
                .useTranscript('One cup of rice and a bowl of dal', 'en'),
          )
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Live transcription is unavailable. Type the description to continue.',
            ),
          ),
        if (voice.listening)
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Text(
              'Recording · stops after $maxVoiceSeconds seconds. Say only the foods and portions.',
            ),
          ),
        if (voice.busy) const LoadingState('Preparing voice entry…'),
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
          enabled: !voice.listening && !voice.busy,
          decoration: const InputDecoration(
            labelText: 'Review or type transcript',
            alignLabelWithHint: true,
          ),
        ),
        TextButton(
          onPressed: voice.listening || voice.busy ? null : useTyped,
          child: const Text('Switch to typed entry'),
        ),
      ],
    );
  }
}
