import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:platewise/core/theme/plate_theme.dart';
import 'package:platewise/core/widgets/widgets.dart';

Widget host(Widget child) => MaterialApp(
  theme: plateTheme(),
  home: Scaffold(body: child),
);

void main() {
  group('buttons', () {
    testWidgets('PrimaryButton shows its label and fires on tap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(PrimaryButton('Save meal', onPressed: () => taps++)),
      );
      expect(find.text('Save meal'), findsOneWidget);
      await tester.tap(find.byType(PrimaryButton));
      expect(taps, 1);
    });

    testWidgets('PrimaryButton is inert and shows progress while busy', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(PrimaryButton('Save meal', busy: true, onPressed: () => taps++)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('SecondaryButton fires on tap and renders its icon', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          SecondaryButton(
            'Retake',
            icon: Icons.camera_alt_outlined,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);
      await tester.tap(find.byType(SecondaryButton));
      expect(taps, 1);
    });

    testWidgets('both buttons meet the 48 px touch target', (tester) async {
      await tester.pumpWidget(
        host(
          Column(
            children: [
              PrimaryButton('One', onPressed: () {}),
              SecondaryButton('Two', onPressed: () {}),
            ],
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(PrimaryButton)).height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.byType(SecondaryButton)).height,
        greaterThanOrEqualTo(48),
      );
    });
  });

  group('states', () {
    testWidgets('ErrorState offers retry only when given a callback', (
      tester,
    ) async {
      await tester.pumpWidget(host(const ErrorState('Something failed')));
      expect(find.text('Something failed'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);

      var retries = 0;
      await tester.pumpWidget(
        host(ErrorState('Something failed', retry: () => retries++)),
      );
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('LoadingState shows its message with a progress indicator', (
      tester,
    ) async {
      await tester.pumpWidget(host(const LoadingState('Analyzing meal')));
      expect(find.text('Analyzing meal'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('EmptyState shows title and message', (tester) async {
      await tester.pumpWidget(
        host(const EmptyState('No meals yet', 'Add your first meal.')),
      );
      expect(find.text('No meals yet'), findsOneWidget);
      expect(find.text('Add your first meal.'), findsOneWidget);
    });
  });

  group('ConfirmationSheet', () {
    Future<void> open(WidgetTester tester, {bool danger = false}) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => ConfirmationSheet.ask(
                context,
                title: 'Delete meal?',
                message: 'This cannot be undone.',
                action: 'Delete',
                danger: danger,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('ask returns true on confirm and false on cancel', (
      tester,
    ) async {
      final results = <bool>[];
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await ConfirmationSheet.ask(
                  context,
                  title: 'Delete meal?',
                  message: 'This cannot be undone.',
                  action: 'Delete',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(results, [true, false]);
    });

    testWidgets('danger paints the action with the destructive color', (
      tester,
    ) async {
      await open(tester, danger: true);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete'),
      );
      expect(button.style?.backgroundColor?.resolve({}), PlateColors.red);
    });
  });

  group('layout', () {
    testWidgets('Wordmark collapses to the mark in a narrow space', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 60, child: Wordmark()),
          ),
        ),
      );
      expect(find.text('PlateWise'), findsNothing);
      expect(find.byType(PlateMark), findsOneWidget);

      await tester.pumpWidget(
        host(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 240, child: Wordmark()),
          ),
        ),
      );
      expect(find.text('PlateWise'), findsOneWidget);
    });

    testWidgets('AdaptiveColumns goes side by side only when wide', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<Axis> pumpAt(double width, {double textScale = 1}) async {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: TextScaler.linear(textScale),
            ),
            child: host(
              const AdaptiveColumns(primary: Text('A'), secondary: Text('B')),
            ),
          ),
        );
        return tester
            .widget<Flex>(
              find.descendant(
                of: find.byType(AdaptiveColumns),
                matching: find.byType(Flex),
              ),
            )
            .direction;
      }

      expect(await pumpAt(1000), Axis.horizontal);
      expect(await pumpAt(500), Axis.vertical);
      expect(await pumpAt(1000, textScale: 2), Axis.vertical);
    });

    testWidgets('PageScroll caps content width', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(const PageScroll(children: [Text('Content')])),
      );
      expect(
        tester.getSize(find.byType(Column).first).width,
        lessThanOrEqualTo(610),
      );
    });

    testWidgets('Standalone shows a title and an optional bottom action', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: plateTheme(),
          home: const Standalone(
            title: 'Review',
            body: Text('Body'),
            bottom: Text('Confirm'),
          ),
        ),
      );
      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    });
  });

  group('content', () {
    testWidgets('PageHeading renders eyebrow, title and detail', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const PageHeading('Today', eyebrow: 'Monday', detail: 'Overview')),
      );
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
    });

    testWidgets('SectionTitle renders detail and trailing widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const SectionTitle(
            'Meals',
            detail: 'Logged today',
            trailing: Text('Edit'),
          ),
        ),
      );
      expect(find.text('Meals'), findsOneWidget);
      expect(find.text('Logged today'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('MetricCard shows label, value and detail', (tester) async {
      await tester.pumpWidget(
        host(
          const MetricCard(label: 'Water', value: '1,500 ml', detail: '75%'),
        ),
      );
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('1,500 ml'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('IndicatorTag shows its label and icon', (tester) async {
      await tester.pumpWidget(
        host(const IndicatorTag('Fits budget', icon: Icons.check)),
      );
      expect(find.text('Fits budget'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('DisclaimerNotice has default text and accepts custom text', (
      tester,
    ) async {
      await tester.pumpWidget(host(const DisclaimerNotice()));
      expect(find.textContaining('not medical advice'), findsOneWidget);
      await tester.pumpWidget(host(const DisclaimerNotice(text: 'Custom')));
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('FoodPicture falls back to a placeholder and honors height', (
      tester,
    ) async {
      await tester.pumpWidget(host(const FoodPicture(height: 200)));
      expect(find.byIcon(Icons.ramen_dining_outlined), findsOneWidget);
      expect(tester.getSize(find.byType(FoodPicture)).height, 200);
    });
  });
}
