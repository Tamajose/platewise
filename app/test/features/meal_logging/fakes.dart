import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:platewise/core/data/core_providers.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/features/meal_logging/data/meal_log_providers.dart';
import 'package:platewise/features/meal_logging/domain/meal_log_repository.dart';
import 'package:platewise/features/meal_logging/domain/voice.dart';

const rice = FoodItem(
  name: 'Steamed rice',
  quantity: 1,
  unit: 'cup',
  grams: 160,
  range: CalorieRange(175, 225),
  nutrients: {Nutrient.protein: 4, Nutrient.carbohydrate: 44},
  nutrientSource: 'seeded',
  provenance: 'demo',
);

MealDraft draftOf(List<FoodItem> items, {String id = 'd1'}) =>
    MealDraft(id: id, source: MealSource.text, items: items);

class FakeSession implements SessionRepository {
  FakeSession({this.demo = false, Capabilities? caps})
    : caps = caps ?? (liveAi: false, banglaText: false, banglaSpeech: false);
  final bool demo;
  final Capabilities caps;
  @override
  bool get isDemo => demo;
  @override
  Future<void> bootstrap() async {}
  @override
  Future<Capabilities> capabilities() async => caps;
}

class FakeOverview implements OverviewRepository {
  FakeOverview([this.value = const Overview()]);
  Overview value;
  int reads = 0;
  @override
  Future<Overview> overview() async {
    reads++;
    return value;
  }
}

class FakeMealLog implements MealLogRepository {
  final calls = <String>[];
  final saved = <MealDraft>[];
  Object? analyzeError, saveError;
  MealDraft result = draftOf([rice]);
  MealDraft? sample;
  Completer<void>? gate;

  @override
  Future<MealDraft> analyzePhoto(String? imagePath) async {
    calls.add('photo:$imagePath');
    await gate?.future;
    if (analyzeError != null) throw analyzeError!;
    return MealDraft(
      id: 'p1',
      source: MealSource.photo,
      items: result.items,
      imagePath: imagePath,
    );
  }

  @override
  Future<MealDraft> analyzeText(
    String description,
    String language, {
    MealSource source = MealSource.text,
  }) async {
    calls.add('text:$description:$language:${source.name}');
    await gate?.future;
    if (analyzeError != null) throw analyzeError!;
    return result;
  }

  @override
  Future<SavedMeal> save(MealDraft draft) async {
    calls.add('save:${draft.id}');
    await gate?.future;
    if (saveError != null) throw saveError!;
    saved.add(draft);
    return SavedMeal(
      draft,
      DateTime.utc(2026, 1, 1),
      'rev',
      draft.range.midpoint,
    );
  }

  @override
  Future<String?> imageUrl(String mealId) async => null;

  @override
  MealDraft? sampleDraft() => sample;
}

class FakeMedia implements MediaStorage {
  final uploads = <Uint8List>[];
  final discarded = <String?>[];
  String? path = 'u/photo.jpg';
  Object? uploadError, discardError;

  @override
  Future<String?> upload(Uint8List bytes) async {
    uploads.add(bytes);
    if (uploadError != null) throw uploadError!;
    return path;
  }

  @override
  Future<void> discard(String? path) async {
    discarded.add(path);
    if (discardError != null) throw discardError!;
  }

  @override
  Future<void> retryCleanup() async {}
}

class FakePicker implements PhotoPicker {
  Uint8List? result = Uint8List.fromList([1, 2, 3]);
  Object? error;
  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    if (error != null) throw error!;
    return result;
  }
}

class FakeRecorder implements VoiceRecorder {
  Object? startError;
  VoiceRecording recording = VoiceRecording(
    bytes: Uint8List.fromList([9]),
    filename: 'meal.m4a',
    mime: 'audio/mp4',
  );
  final events = <String>[];
  @override
  Future<void> start() async {
    events.add('start');
    if (startError != null) throw startError!;
  }

  @override
  Future<VoiceRecording> stop() async {
    events.add('stop');
    return recording;
  }

  @override
  Future<void> cancel() async => events.add('cancel');
  @override
  Future<void> dispose() async => events.add('dispose');
}

class FakeTranscriber implements SpeechTranscriber {
  String text = 'rice and dal';
  Object? error;
  final languages = <String>[];
  @override
  Future<String> transcribe(VoiceRecording recording, String language) async {
    languages.add(language);
    if (error != null) throw error!;
    return text;
  }
}

/// Every fake a meal logging screen or controller needs, with overrides.
class Rig {
  Rig({bool demo = false, Capabilities? caps, Overview? overview})
    : session = FakeSession(demo: demo, caps: caps),
      overviews = FakeOverview(overview ?? const Overview());

  final FakeSession session;
  final FakeOverview overviews;
  final meals = FakeMealLog();
  final media = FakeMedia();
  final picker = FakePicker();
  final recorder = FakeRecorder();
  final transcriber = FakeTranscriber();

  List<Override> get overrides => [
    sessionRepositoryProvider.overrideWithValue(session),
    overviewRepositoryProvider.overrideWithValue(overviews),
    mealLogRepositoryProvider.overrideWithValue(meals),
    mediaStorageProvider.overrideWithValue(media),
    photoPickerProvider.overrideWithValue(picker),
    speechTranscriberProvider.overrideWithValue(transcriber),
    voiceRecorderProvider.overrideWith((ref) => recorder),
    idGeneratorProvider.overrideWithValue(() => 'new-id'),
  ];

  ProviderContainer container() {
    final container = ProviderContainer(overrides: overrides);
    return container;
  }
}
