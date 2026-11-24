import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:platewise/app/app.dart';
import 'package:platewise/app/composition.dart';
import 'package:platewise/core/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:timezone/data/latest_all.dart' as timezone;

/// The whole demo app, wired the way `main.dart` wires it, driven through the
/// journey the browser smoke test and the handoff script follow. It runs with
/// the unit tests, so a broken journey fails the build before anyone opens a
/// browser.

Future<void> tap(WidgetTester tester, Finder target) async {
  // A snack bar from the last step can cover the target. Let it time out.
  if (find.byType(SnackBar).evaluate().isNotEmpty) {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) =>
    tap(tester, find.text(text).first);

/// A destination in the navigation bar, not a heading that shares its name.
Finder destination(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  setUpAll(timezone.initializeTimeZones);

  testWidgets(
    'a person explores the sample day, logs, compares and clears it',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.view.physicalSize = const Size(402, 870);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final overrides = await composeOverrides(
        const AppConfig(mode: 'demo'),
        preferences: SharedPreferencesAsync(),
      );
      await tester.pumpWidget(
        ProviderScope(overrides: overrides, child: const PlateWiseApp()),
      );
      await tester.pumpAndSettle();

      // A new person meets the welcome screen and opens the sample day.
      expect(find.text('Decide before you eat'), findsOneWidget);
      await tapText(tester, 'Explore a sample day');
      expect(find.text('Daily calorie estimate'), findsOneWidget);
      expect(find.text('Demo mode'), findsOneWidget);

      // Log the labeled sample photo estimate.
      await tapText(tester, 'Log meal');
      expect(find.text('What did you eat?'), findsOneWidget);
      await tapText(tester, 'Review sample photo estimate');
      expect(find.text('Check your estimate'), findsOneWidget);
      await tapText(tester, 'Confirm and log meal');
      expect(find.text('Chicken tikka rice bowl · Masoor dal'), findsOneWidget);

      // Compare the sample menu against a typed budget and log the winner.
      await tap(tester, destination('Decide'));
      await tapText(tester, 'Set a meal budget');
      await tester.enterText(
        find.widgetWithText(TextField, 'Meal budget (kcal)'),
        '650',
      );
      await tester.pump();
      await tapText(tester, 'Review sample menu');
      expect(find.text('Check menu options'), findsOneWidget);
      await tapText(tester, 'Compare selected dishes');
      expect(find.text('Comparison results'), findsOneWidget);
      expect(find.text('650 kcal meal budget'), findsOneWidget);
      await tapText(tester, 'Choose this meal');
      expect(find.text('Check your estimate'), findsOneWidget);
      await tapText(tester, 'Confirm and log meal');
      expect(find.text('Meals today'), findsOneWidget);

      // Nearby offers the demo sample menus.
      await tap(tester, destination('Nearby'));
      await tapText(tester, 'Sample menus');
      expect(find.text('Review this meal'), findsWidgets);

      // Water, with undo.
      await tap(tester, destination('Today'));
      await tapText(tester, '+250 ml');
      expect(find.text('Added 250 ml'), findsOneWidget);

      // Progress and Settings.
      await tap(tester, destination('Progress'));
      expect(find.text('Intake and target'), findsOneWidget);
      await tap(tester, find.byTooltip('Settings and profile'));
      expect(find.text('Profile & privacy'), findsOneWidget);

      // Clearing the demo returns to the welcome screen, and a fresh profile
      // opens an empty Today.
      await tapText(tester, 'Clear demo data');
      await tap(tester, find.widgetWithText(FilledButton, 'Delete data'));
      expect(find.text('Decide before you eat'), findsOneWidget);
      await tapText(tester, 'Set up my profile');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Height (cm)'),
        '170',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Weight (kg)'),
        '69',
      );
      await tapText(tester, 'Continue to Today');
      expect(find.text('No meals logged yet'), findsOneWidget);
    },
  );
}
