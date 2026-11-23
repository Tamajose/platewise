import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:platewise/core/theme/plate_theme.dart';
import 'package:platewise/core/widgets/widgets.dart';

Future<void> show(WidgetTester tester, Confidence confidence) =>
    tester.pumpWidget(
      MaterialApp(
        theme: plateTheme(),
        home: Scaffold(body: ConfidenceBadge(confidence)),
      ),
    );

void main() {
  testWidgets('names each level', (tester) async {
    for (final level in Confidence.values) {
      await show(tester, level);
      final name = '${level.name[0].toUpperCase()}${level.name.substring(1)}';
      expect(find.text('$name confidence'), findsOneWidget);
    }
  });

  testWidgets('low confidence uses the warning colors', (tester) async {
    await show(tester, Confidence.low);
    final tag = tester.widget<IndicatorTag>(find.byType(IndicatorTag));
    expect(tag.background, PlateColors.amber);
    expect(tag.foreground, PlateColors.amberInk);
  });

  testWidgets('medium and high use the calm colors', (tester) async {
    for (final level in [Confidence.medium, Confidence.high]) {
      await show(tester, level);
      final tag = tester.widget<IndicatorTag>(find.byType(IndicatorTag));
      expect(tag.background, PlateColors.sage);
      expect(tag.foreground, PlateColors.forest);
    }
  });
}
