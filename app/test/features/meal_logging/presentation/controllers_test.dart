import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/core/l10n/app_language.dart';
import 'package:platewise/core/l10n/language_providers.dart';
import 'package:platewise/core/presentation/review_args.dart';
import 'package:platewise/core/presentation/session_state.dart';
import 'package:platewise/features/meal_logging/domain/voice.dart';
import 'package:platewise/features/meal_logging/presentation/capture_controller.dart';
import 'package:platewise/features/meal_logging/presentation/review_controller.dart';
import 'package:platewise/features/meal_logging/presentation/voice_controller.dart';

import '../fakes.dart';

/// Keeps an autoDispose provider alive for the length of a test.
T hold<T>(ProviderContainer container, ProviderListenable<T> provider) {
  container.listen(provider, (_, _) {});
  return container.read(provider);
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  group('capture', () {
    test(
      'starts with the language of the app when Bangla is available',
      () async {
        final rig = Rig(
          caps: (liveAi: true, banglaText: true, banglaSpeech: false),
        );
        final container = rig.container();
        addTearDown(container.dispose);
        await container.read(appLanguageProvider.notifier).set(AppLanguage.bn);
        await container.read(capabilitiesProvider.future);
        expect(hold(container, captureControllerProvider).language, 'bn');
      },
    );

    test(
      'stays in English when the deployment has no Bangla analysis',
      () async {
        final rig = Rig(
          caps: (liveAi: true, banglaText: false, banglaSpeech: false),
        );
        final container = rig.container();
        addTearDown(container.dispose);
        await container.read(appLanguageProvider.notifier).set(AppLanguage.bn);
        await container.read(capabilitiesProvider.future);
        expect(hold(container, captureControllerProvider).language, 'en');
      },
    );

    test('estimating needs a photo or at least two characters', () {
      final container = Rig().container();
      addTearDown(container.dispose);
      final controller = container.read(captureControllerProvider.notifier);
      hold(container, captureControllerProvider);
      expect(container.read(captureControllerProvider).canEstimate, isFalse);
      controller.selectMethod(CaptureMethod.text);
      controller.setDescription(' a ');
      expect(container.read(captureControllerProvider).canEstimate, isFalse);
      controller.setDescription('ab');
      expect(container.read(captureControllerProvider).canEstimate, isTrue);
    });

    test('a text estimate sends the trimmed text and language', () async {
      final rig = Rig();
      final container = rig.container();
      addTearDown(container.dispose);
      hold(container, captureControllerProvider);
      final controller = container.read(captureControllerProvider.notifier)
        ..selectMethod(CaptureMethod.text)
        ..setDescription('  rice  ');
      final draft = await controller.estimate();
      expect(draft, isNotNull);
      expect(rig.meals.calls, ['text:rice:en:text']);
      expect(container.read(captureControllerProvider).busy, isFalse);
    });

    test('a voice estimate is recorded as voice', () async {
      final rig = Rig();
      final container = rig.container();
      addTearDown(container.dispose);
      hold(container, captureControllerProvider);
      final controller = container.read(captureControllerProvider.notifier)
        ..selectMethod(CaptureMethod.voice)
        ..useTranscript('rice', 'bn');
      await controller.estimate();
      expect(rig.meals.calls, ['text:rice:bn:voice']);
    });

    test('a transcript is cut to the maximum length', () {
      final container = Rig().container();
      addTearDown(container.dispose);
      hold(container, captureControllerProvider);
      container
          .read(captureControllerProvider.notifier)
          .useTranscript('x' * 900, 'en');
      expect(
        container.read(captureControllerProvider).description.length,
        maxDescriptionLength,
      );
    });

    test('a photo is uploaded, then analyzed from its path', () async {
      final rig = Rig();
      final container = rig.container();
      addTearDown(container.dispose);
      hold(container, captureControllerProvider);
      final controller = container.read(captureControllerProvider.notifier);
      await controller.pickPhoto(PhotoSource.camera);
      expect(container.read(captureControllerProvider).photo, isNotNull);
      final draft = await controller.estimate();
      expect(rig.media.uploads, hasLength(1));
      expect(rig.meals.calls, ['photo:u/photo.jpg']);
      expect(draft!.imagePath, 'u/photo.jpg');
      expect(rig.media.discarded, isEmpty);
    });

    test('a failed estimate deletes the uploaded photo', () async {
      final rig = Rig();
      rig.meals.analyzeError = const Failure('Try later.');
      final container = rig.container();
      addTearDown(container.dispose);
      hold(container, captureControllerProvider);
      final controller = container.read(captureControllerProvider.notifier);
      await controller.pickPhoto(PhotoSource.gallery);
      expect(await controller.estimate(), isNull);
      expect(rig.media.discarded, ['u/photo.jpg']);
      final state = container.read(captureControllerProvider);
      expect(state.error, 'Try later.');
      expect(state.busy, isFalse);
    });

    test('a failed cleanup is mentioned', () async {
      final rig = Rig();
      rig.meals.analyzeError = const Failure('Try later.');
      rig.media.discardError = StateError('x');
      final container = rig.container();
      addTearDown(container.dispose);
      hold(container, captureControllerProvider);
      final controller = container.read(captureControllerProvider.notifier);
      await controller.pickPhoto(PhotoSource.gallery);
      await controller.estimate();
      expect(
        container.read(captureControllerProvider).error,
        'Try later. Photo cleanup may still be pending.',
      );
    });

    test('a failed upload leaves nothing to clean up', () async {
      final rig = Rig();
      rig.media.uploadError = const Failure('Upload failed.');
      final container = rig.container();
      addTearDown(container.dispose);
      hold(container, captureControllerProvider);
      final controller = container.read(captureControllerProvider.notifier);
      await controller.pickPhoto(PhotoSource.gallery);
      expect(await controller.estimate(), isNull);
      expect(rig.media.discarded, isEmpty);
      expect(container.read(captureControllerProvider).error, 'Upload failed.');
    });

    test(
      'a picker failure shows its message and a cancel changes nothing',
      () async {
        final rig = Rig();
        final container = rig.container();
        addTearDown(container.dispose);
        hold(container, captureControllerProvider);
        final controller = container.read(captureControllerProvider.notifier);
        rig.picker.error = const Failure('No camera.');
        await controller.pickPhoto(PhotoSource.camera);
        expect(container.read(captureControllerProvider).error, 'No camera.');
        rig.picker
          ..error = null
          ..result = null;
        await controller.pickPhoto(PhotoSource.camera);
        final state = container.read(captureControllerProvider);
        expect(state.photo, isNull);
        expect(state.error, isNull);
        expect(state.busy, isFalse);
      },
    );

    test('a second estimate is ignored while one is running', () async {
      final rig = Rig();
      rig.meals.gate = Completer<void>();
      final container = rig.container();
      addTearDown(container.dispose);
      hold(container, captureControllerProvider);
      final controller = container.read(captureControllerProvider.notifier)
        ..selectMethod(CaptureMethod.text)
        ..setDescription('rice');
      final first = controller.estimate();
      expect(await controller.estimate(), isNull);
      rig.meals.gate!.complete();
      await first;
      expect(rig.meals.calls, hasLength(1));
    });

    test('closing the screen mid-estimate deletes the new photo', () async {
      final rig = Rig();
      rig.meals.gate = Completer<void>();
      final container = rig.container();
      addTearDown(container.dispose);
      final subscription = container.listen(
        captureControllerProvider,
        (_, _) {},
      );
      final controller = container.read(captureControllerProvider.notifier);
      await controller.pickPhoto(PhotoSource.camera);
      final pending = controller.estimate();
      await Future<void>.delayed(Duration.zero);
      subscription.close();
      await Future<void>.delayed(Duration.zero);
      rig.meals.gate!.complete();
      expect(await pending, isNull);
      expect(rig.media.discarded, ['u/photo.jpg']);
    });

    test('manual and sample reviews', () {
      final rig = Rig(demo: true);
      final container = rig.container();
      addTearDown(container.dispose);
      hold(container, captureControllerProvider);
      final controller = container.read(captureControllerProvider.notifier);
      final manual = controller.manualReview();
      expect(manual.draft.source, MealSource.manual);
      expect(manual.draft.id, 'new-id');
      expect(manual.draft.items, isEmpty);
      expect(controller.sampleReview(), isNull);
      rig.meals.sample = draftOf([rice], id: 's1');
      final sample = controller.sampleReview()!;
      expect(sample.editorial, isTrue);
      expect(sample.draft.id, 's1');
    });
  });

  group('review', () {
    ReviewArgs args([MealDraft? draft, bool discard = true]) =>
        ReviewArgs(draft ?? draftOf([rice]), discardOnLeave: discard);

    test('adding, replacing and removing foods revises the draft', () {
      final container = Rig().container();
      addTearDown(container.dispose);
      final a = args();
      hold(container, reviewControllerProvider(a));
      final controller = container.read(reviewControllerProvider(a).notifier);
      controller.putFood(null, rice);
      expect(
        container.read(reviewControllerProvider(a)).draft.items,
        hasLength(2),
      );
      controller.removeFood(0);
      final draft = container.read(reviewControllerProvider(a)).draft;
      expect(draft.items, hasLength(1));
      expect(draft.edited, isTrue);
      expect(draft.confidence, Confidence.low);
    });

    test('an empty draft cannot be saved and nothing is sent', () async {
      final rig = Rig();
      final container = rig.container();
      addTearDown(container.dispose);
      final a = args(draftOf([]));
      hold(container, reviewControllerProvider(a));
      final controller = container.read(reviewControllerProvider(a).notifier);
      expect(container.read(reviewControllerProvider(a)).canSave, isFalse);
      expect(await controller.save(), isFalse);
      expect(rig.meals.calls, isEmpty);
    });

    test('saving stores the meal and refreshes the overview', () async {
      final rig = Rig();
      final container = rig.container();
      addTearDown(container.dispose);
      await container.read(overviewProvider.future);
      final a = args();
      hold(container, reviewControllerProvider(a));
      final saved = await container
          .read(reviewControllerProvider(a).notifier)
          .save();
      expect(saved, isTrue);
      expect(rig.meals.saved.single.id, 'd1');
      expect(container.read(reviewControllerProvider(a)).saved, isTrue);
      await container.read(overviewProvider.future);
      expect(rig.overviews.reads, 2);
    });

    test('a failed save keeps the draft and says why', () async {
      final rig = Rig();
      rig.meals.saveError = const Failure('This meal changed.');
      final container = rig.container();
      addTearDown(container.dispose);
      final a = args();
      hold(container, reviewControllerProvider(a));
      final controller = container.read(reviewControllerProvider(a).notifier);
      expect(await controller.save(), isFalse);
      final state = container.read(reviewControllerProvider(a));
      expect(state.error, 'This meal changed.');
      expect(state.busy, isFalse);
      expect(state.saved, isFalse);
      rig.meals.saveError = null;
      expect(await controller.save(), isTrue);
      expect(container.read(reviewControllerProvider(a)).error, isNull);
    });

    test('too large a meal cannot be saved', () {
      final container = Rig().container();
      addTearDown(container.dispose);
      const feast = FoodItem(
        name: 'Feast',
        quantity: 1,
        unit: 'serving',
        range: CalorieRange(6000, 6000),
      );
      final a = args(draftOf([feast, feast, feast, feast]));
      final state = hold(container, reviewControllerProvider(a));
      expect(state.tooLarge, isTrue);
      expect(state.canSave, isFalse);
    });

    test('at 16 foods no more can be added', () {
      final container = Rig().container();
      addTearDown(container.dispose);
      final a = args(draftOf(List.filled(16, rice)));
      expect(hold(container, reviewControllerProvider(a)).canAddFood, isFalse);
    });

    test('leaving unsaved deletes the uploaded photo', () async {
      final rig = Rig();
      final container = rig.container();
      addTearDown(container.dispose);
      final a = args(
        const MealDraft(
          id: 'p',
          source: MealSource.photo,
          items: [rice],
          imagePath: 'u/p.jpg',
        ),
      );
      hold(container, reviewControllerProvider(a));
      await container
          .read(reviewControllerProvider(a).notifier)
          .discardIfAbandoned();
      expect(rig.media.discarded, ['u/p.jpg']);
    });

    test('a saved meal, a saved draft or an opt-out keeps the photo', () async {
      final rig = Rig();
      final container = rig.container();
      addTearDown(container.dispose);
      const photo = MealDraft(
        id: 'p',
        source: MealSource.photo,
        items: [rice],
        imagePath: 'u/p.jpg',
      );
      // Saved during this visit.
      final a = args(photo);
      hold(container, reviewControllerProvider(a));
      await container.read(reviewControllerProvider(a).notifier).save();
      await container
          .read(reviewControllerProvider(a).notifier)
          .discardIfAbandoned();
      // Opening an existing meal.
      final b = args(
        const MealDraft(
          id: 'q',
          source: MealSource.photo,
          items: [rice],
          imagePath: 'u/q.jpg',
          expectedUpdatedAt: 'rev',
        ),
      );
      hold(container, reviewControllerProvider(b));
      await container
          .read(reviewControllerProvider(b).notifier)
          .discardIfAbandoned();
      // The caller owns the photo.
      final c = args(photo, false);
      hold(container, reviewControllerProvider(c));
      await container
          .read(reviewControllerProvider(c).notifier)
          .discardIfAbandoned();
      expect(rig.media.discarded, isEmpty);
    });

    test('a failed cleanup is ignored', () async {
      final rig = Rig();
      rig.media.discardError = StateError('x');
      final container = rig.container();
      addTearDown(container.dispose);
      final a = args(
        const MealDraft(
          id: 'p',
          source: MealSource.photo,
          items: [rice],
          imagePath: 'u/p.jpg',
        ),
      );
      hold(container, reviewControllerProvider(a));
      await container
          .read(reviewControllerProvider(a).notifier)
          .discardIfAbandoned();
    });
  });

  group('voice', () {
    ProviderContainer open(Rig rig) {
      final container = rig.container();
      addTearDown(container.dispose);
      hold(container, captureControllerProvider);
      hold(container, voiceControllerProvider);
      return container;
    }

    test('records, transcribes and fills the description', () async {
      final rig = Rig();
      final container = open(rig);
      final voice = container.read(voiceControllerProvider.notifier);
      voice.setLocale('bn');
      await voice.start();
      expect(container.read(voiceControllerProvider).listening, isTrue);
      await voice.stop();
      expect(rig.recorder.events, ['start', 'stop']);
      expect(rig.transcriber.languages, ['bn']);
      final capture = container.read(captureControllerProvider);
      expect(capture.description, 'rice and dal');
      expect(capture.language, 'bn');
      final state = container.read(voiceControllerProvider);
      expect(state.listening, isFalse);
      expect(state.busy, isFalse);
      expect(state.error, isNull);
    });

    test('a denied microphone shows its message', () async {
      final rig = Rig();
      rig.recorder.startError = const Failure('Microphone denied.');
      final container = open(rig);
      await container.read(voiceControllerProvider.notifier).start();
      final state = container.read(voiceControllerProvider);
      expect(state.error, 'Microphone denied.');
      expect(state.listening, isFalse);
    });

    test('an unexpected recorder error gets a safe message', () async {
      final rig = Rig();
      rig.recorder.startError = StateError('plugin internals');
      final container = open(rig);
      await container.read(voiceControllerProvider.notifier).start();
      final error = container.read(voiceControllerProvider).error!;
      expect(error, contains('Recording is unavailable here'));
      expect(error, isNot(contains('plugin')));
    });

    test('a recording over 2 MB is refused before transcription', () async {
      final rig = Rig();
      rig.recorder.recording = VoiceRecording(
        bytes: Uint8List(maxVoiceBytes + 1),
        filename: 'meal.m4a',
        mime: 'audio/mp4',
      );
      final container = open(rig);
      final voice = container.read(voiceControllerProvider.notifier);
      await voice.start();
      await voice.stop();
      expect(rig.transcriber.languages, isEmpty);
      expect(
        container.read(voiceControllerProvider).error,
        'Use a recording under 2 MB, or type your meal.',
      );
    });

    test('a transcription failure keeps the existing text', () async {
      final rig = Rig();
      rig.transcriber.error = const Failure('Speech is offline.');
      final container = open(rig);
      container.read(captureControllerProvider.notifier).setDescription('keep');
      final voice = container.read(voiceControllerProvider.notifier);
      await voice.start();
      await voice.stop();
      expect(
        container.read(voiceControllerProvider).error,
        'Speech is offline.',
      );
      expect(container.read(captureControllerProvider).description, 'keep');
    });

    test('stopping without recording does nothing', () async {
      final rig = Rig();
      final container = open(rig);
      await container.read(voiceControllerProvider.notifier).stop();
      expect(rig.recorder.events, isEmpty);
    });
  });
}
