import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as im;
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/core/presentation/review_args.dart';
import 'package:platewise/core/presentation/routes.dart';
import 'package:platewise/core/theme/plate_theme.dart';
import 'package:platewise/features/meal_logging/presentation/capture_screen.dart';
import 'package:platewise/features/meal_logging/presentation/review_screen.dart';

import '../fakes.dart';

Uint8List tinyPng() =>
    Uint8List.fromList(im.encodePng(im.Image(width: 8, height: 8)));

Future<void> open(WidgetTester tester, Rig rig, {ReviewArgs? review}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: review == null ? Routes.home : Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => review == null
                  ? context.push(Routes.log)
                  : context.push(Routes.review, extra: review),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(path: Routes.log, builder: (_, _) => const CaptureScreen()),
      GoRoute(
        path: Routes.review,
        builder: (_, state) => ReviewScreen(state.extra! as ReviewArgs),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: rig.overrides,
      child: MaterialApp.router(theme: plateTheme(), routerConfig: router),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder field(String label) => find.widgetWithText(TextField, label);

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> addManualFood(WidgetTester tester) async {
  await tapText(tester, 'Add food');
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Food name'),
    'Dal',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Low estimate (kcal)'),
    '140',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'High estimate (kcal)'),
    '220',
  );
  await tapText(tester, 'Apply food changes');
}

void main() {
  group('capture screen', () {
    testWidgets('estimate starts disabled and a typed meal reaches review', (
      tester,
    ) async {
      final rig = Rig();
      await open(tester, rig);
      expect(find.text('What did you eat?'), findsOneWidget);
      FilledButton estimateButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Estimate meal'),
      );
      expect(estimateButton().onPressed, isNull);

      await tapText(tester, 'Text');
      await tester.enterText(field('Describe the meal'), 'rice');
      await tester.pump();
      expect(estimateButton().onPressed, isNotNull);

      await tapText(tester, 'Estimate meal');
      expect(rig.meals.calls, ['text:rice:en:text']);
      expect(find.text('Check your estimate'), findsOneWidget);
      expect(find.text('Steamed rice'), findsOneWidget);
      expect(find.text('175–225 kcal'), findsOneWidget);
    });

    testWidgets('confirming a meal logs it and returns to the start', (
      tester,
    ) async {
      final rig = Rig();
      await open(tester, rig);
      await tapText(tester, 'Text');
      await tester.enterText(field('Describe the meal'), 'rice');
      await tester.pump();
      await tapText(tester, 'Estimate meal');
      await tapText(tester, 'Confirm and log meal');
      expect(rig.meals.saved.single.items.single.name, 'Steamed rice');
      expect(find.text('open'), findsOneWidget);
      expect(find.text('Meal added to Today'), findsOneWidget);
    });

    testWidgets('a failed estimate shows its message and stays', (
      tester,
    ) async {
      final rig = Rig();
      rig.meals.analyzeError = const Failure('The AI is busy.');
      await open(tester, rig);
      await tapText(tester, 'Text');
      await tester.enterText(field('Describe the meal'), 'rice');
      await tester.pump();
      await tapText(tester, 'Estimate meal');
      expect(find.text('The AI is busy.'), findsOneWidget);
      expect(find.text('Log meal'), findsOneWidget);
    });

    testWidgets(
      'a low-confidence photo shows guidance instead of nutrition values',
      (tester) async {
        final rig = Rig();
        rig.meals.analyzeError = const Failure(
          'I’m not confident enough to estimate this meal from the photo. Try a clearer photo or describe the dishes and portions, or enter the meal manually. If you need nutrition guidance for a health decision, consult a qualified healthcare professional.',
        );
        rig.picker.result = tinyPng();
        await open(tester, rig);
        await tapText(tester, 'Gallery');
        await tapText(tester, 'Estimate meal');

        expect(
          find.textContaining('not confident enough to estimate'),
          findsOneWidget,
        );
        expect(
          find.textContaining('qualified healthcare professional'),
          findsOneWidget,
        );
        expect(find.text('Enter meal manually'), findsOneWidget);
        expect(find.text('Check your estimate'), findsNothing);
        expect(find.text('175–225 kcal'), findsNothing);
        expect(rig.media.discarded, ['u/photo.jpg']);
      },
    );

    testWidgets('a photo is chosen, then estimated', (tester) async {
      final rig = Rig();
      rig.picker.result = tinyPng();
      await open(tester, rig);
      expect(find.text('Add a photo of your meal'), findsOneWidget);
      await tapText(tester, 'Gallery');
      expect(find.text('Add a photo of your meal'), findsNothing);
      expect(find.text('Retake'), findsOneWidget);
      await tapText(tester, 'Estimate meal');
      expect(rig.media.uploads, hasLength(1));
      expect(rig.meals.calls, ['photo:u/photo.jpg']);
      expect(find.text('Check your estimate'), findsOneWidget);
    });

    testWidgets('a photo that cannot be read says so', (tester) async {
      final rig = Rig();
      rig.picker.error = const Failure('Photo access is unavailable.');
      await open(tester, rig);
      await tapText(tester, 'Camera');
      expect(find.text('Photo access is unavailable.'), findsOneWidget);
    });

    testWidgets('leaving review without saving deletes the photo', (
      tester,
    ) async {
      final rig = Rig();
      rig.picker.result = tinyPng();
      await open(tester, rig);
      await tapText(tester, 'Gallery');
      await tapText(tester, 'Estimate meal');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(rig.media.discarded, ['u/photo.jpg']);
      expect(find.text('Log meal'), findsOneWidget);
    });

    testWidgets('demo mode offers a sample photo estimate', (tester) async {
      final rig = Rig(demo: true);
      rig.meals.sample = draftOf([rice], id: 'sample');
      await open(tester, rig);
      expect(find.text('Review sample photo estimate'), findsOneWidget);
      await tapText(tester, 'Review sample photo estimate');
      expect(find.text('Check your estimate'), findsOneWidget);
      expect(find.text('Illustrative demo estimate'), findsNothing);
    });

    testWidgets('a live build has no sample button', (tester) async {
      await open(tester, Rig());
      expect(find.text('Review sample photo estimate'), findsNothing);
    });

    testWidgets('typed entry offers Bangla only when the service does', (
      tester,
    ) async {
      final rig = Rig(
        caps: (liveAi: true, banglaText: true, banglaSpeech: false),
      );
      await open(tester, rig);
      await tapText(tester, 'Text');
      expect(find.text('Input language'), findsOneWidget);
    });

    testWidgets('typed entry hides the language without Bangla support', (
      tester,
    ) async {
      await open(tester, Rig());
      await tapText(tester, 'Text');
      expect(find.text('Input language'), findsNothing);
    });

    testWidgets('manual entry opens an empty review', (tester) async {
      await open(tester, Rig());
      await tapText(tester, 'Enter meal manually');
      expect(find.text('Add a food'), findsOneWidget);
      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirm and log meal'),
      );
      expect(confirm.onPressed, isNull);
    });
  });

  group('voice tab', () {
    testWidgets('demo mode fills a sample transcript', (tester) async {
      await open(tester, Rig(demo: true));
      await tapText(tester, 'Voice');
      await tapText(tester, 'Use sample transcript');
      expect(find.text('One cup of rice and a bowl of dal'), findsOneWidget);
    });

    testWidgets('records and transcribes when live speech is available', (
      tester,
    ) async {
      final rig = Rig(
        caps: (liveAi: true, banglaText: false, banglaSpeech: true),
      );
      rig.transcriber.text = 'two eggs';
      await open(tester, rig);
      await tapText(tester, 'Voice');
      await tapText(tester, 'Record voice note');
      expect(find.text('Stop and transcribe'), findsOneWidget);
      expect(find.textContaining('Recording ·'), findsOneWidget);
      await tapText(tester, 'Stop and transcribe');
      expect(find.text('two eggs'), findsOneWidget);
      expect(rig.recorder.events, ['start', 'stop']);
    });

    testWidgets('without live speech outside demo it asks for typing', (
      tester,
    ) async {
      await open(tester, Rig());
      await tapText(tester, 'Voice');
      expect(
        find.textContaining('Live transcription is unavailable'),
        findsOneWidget,
      );
    });

    testWidgets('switching to typed entry keeps the transcript', (
      tester,
    ) async {
      await open(tester, Rig(demo: true));
      await tapText(tester, 'Voice');
      await tapText(tester, 'Use sample transcript');
      await tapText(tester, 'Switch to typed entry');
      expect(field('Describe the meal'), findsOneWidget);
      expect(
        tester.widget<TextField>(field('Describe the meal')).controller!.text,
        'One cup of rice and a bowl of dal',
      );
    });
  });

  group('review screen', () {
    ReviewArgs args([List<FoodItem> items = const [rice]]) =>
        ReviewArgs(draftOf(items));

    testWidgets('shows the total, confidence, foods and nutrients', (
      tester,
    ) async {
      await open(tester, Rig(), review: args());
      expect(find.text('Typed description · estimated total'), findsOneWidget);
      expect(find.text('175–225 kcal'), findsOneWidget);
      expect(find.text('Low confidence'), findsOneWidget);
      expect(find.text('1 cup · 175–225 kcal'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.textContaining('≈4 g'), findsOneWidget);
      expect(find.text('Unavailable'), findsWidgets);
    });

    testWidgets('removing the last food disables confirming', (tester) async {
      await open(tester, Rig(), review: args());
      await tester.tap(find.byTooltip('Remove Steamed rice'));
      await tester.pumpAndSettle();
      expect(find.text('Add a food'), findsOneWidget);
      final confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirm and log meal'),
      );
      expect(confirm.onPressed, isNull);
    });

    testWidgets('a food can be added by hand', (tester) async {
      final rig = Rig();
      await open(tester, rig, review: args([]));
      await addManualFood(tester);
      expect(find.text('1 serving · 140–220 kcal'), findsOneWidget);
      await tapText(tester, 'Confirm and log meal');
      expect(rig.meals.saved.single.items.single.name, 'Dal');
      expect(rig.meals.saved.single.edited, isTrue);
    });

    testWidgets('the editor rejects an empty name and a bad quantity', (
      tester,
    ) async {
      await open(tester, Rig(), review: args([]));
      await tapText(tester, 'Add food');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantity'),
        '0',
      );
      await tapText(tester, 'Apply food changes');
      expect(find.text('Enter a food name.'), findsOneWidget);
      expect(
        find.text('Enter 0.001 to 3,000 using up to three decimal places.'),
        findsOneWidget,
      );
      expect(find.text('Enter 0–6,000 kcal.'), findsNWidgets(2));
    });

    testWidgets('the editor rejects a high estimate below the low one', (
      tester,
    ) async {
      await open(tester, Rig(), review: args([]));
      await tapText(tester, 'Add food');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Food name'),
        'Dal',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Low estimate (kcal)'),
        '300',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'High estimate (kcal)'),
        '200',
      );
      await tapText(tester, 'Apply food changes');
      expect(
        find.text('The high estimate must be at least the low estimate.'),
        findsOneWidget,
      );
    });

    testWidgets('changing only the quantity rescales the food', (tester) async {
      await open(tester, Rig(), review: args());
      await tester.tap(find.byTooltip('Edit Steamed rice'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantity'),
        '2',
      );
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Low estimate (kcal)'),
            )
            .controller!
            .text,
        '350',
      );
      await tapText(tester, 'Apply food changes');
      expect(find.text('2 cup · 350–450 kcal'), findsOneWidget);
      expect(find.textContaining('≈8 g'), findsOneWidget);
    });

    testWidgets('renaming a food clears its range and nutrients', (
      tester,
    ) async {
      await open(tester, Rig(), review: args());
      await tester.tap(find.byTooltip('Edit Steamed rice'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Food name'),
        'Fried rice',
      );
      await tester.pump();
      expect(
        find.textContaining('Enter a new range for this food or unit'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Low estimate (kcal)'),
        '300',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'High estimate (kcal)'),
        '380',
      );
      await tapText(tester, 'Apply food changes');
      expect(find.text('1 cup · 300–380 kcal'), findsOneWidget);
      expect(find.text('Unavailable'), findsNWidgets(5));
    });

    testWidgets('a failed save keeps the screen and says why', (tester) async {
      final rig = Rig();
      rig.meals.saveError = const Failure('This meal changed. Open it again.');
      await open(tester, rig, review: args());
      await tapText(tester, 'Confirm and log meal');
      expect(find.text('This meal changed. Open it again.'), findsOneWidget);
      expect(find.text('Check your estimate'), findsOneWidget);
    });

    testWidgets('a saved meal opens for editing', (tester) async {
      final rig = Rig();
      final saved = ReviewArgs(
        const MealDraft(
          id: 'm1',
          source: MealSource.text,
          items: [rice],
          expectedUpdatedAt: 'rev-1',
        ),
      );
      await open(tester, rig, review: saved);
      expect(find.text('Edit meal'), findsOneWidget);
      expect(find.text('Saved meal'), findsOneWidget);
      await tapText(tester, 'Save changes');
      expect(find.text('Meal updated'), findsOneWidget);
      expect(rig.meals.calls, ['save:m1']);
    });

    testWidgets('a meal that is too large explains why it cannot be saved', (
      tester,
    ) async {
      const feast = FoodItem(
        name: 'Feast',
        quantity: 1,
        unit: 'serving',
        range: CalorieRange(6000, 6000),
      );
      await open(tester, Rig(), review: args([feast, feast, feast, feast]));
      expect(
        find.textContaining('exceeds the supported meal size'),
        findsOneWidget,
      );
    });

    testWidgets('the demo fixture is labeled as illustrative', (tester) async {
      await open(
        tester,
        Rig(),
        review: ReviewArgs(
          const MealDraft(
            id: 'x',
            source: MealSource.photo,
            items: [rice],
            model: 'demo-fixtures',
          ),
          editorial: true,
        ),
      );
      expect(find.text('Illustrative demo estimate'), findsOneWidget);
    });
  });
}
