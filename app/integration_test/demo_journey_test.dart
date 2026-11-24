import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:platewise/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

/// Runs the real app on a device or emulator. Unlike the widget tests, it uses
/// the real plugins and storage:
///
///     flutter test integration_test -d <device-id> --dart-define=PLATEWISE_MODE=demo
///
/// The same journey runs without a device in `test/app/demo_journey_test.dart`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo app boots, creates sample data and opens capture', (
    tester,
  ) async {
    await SharedPreferencesAsync().remove('platewise.demo.v1');
    await app.main();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Explore a sample day'));
    await tester.tap(find.text('Explore a sample day'));
    await tester.pumpAndSettle();
    expect(find.text('Daily calorie estimate'), findsOneWidget);
    await tester.tap(find.text('Log meal'));
    await tester.pumpAndSettle();
    expect(find.text('What did you eat?'), findsOneWidget);
  });
}
