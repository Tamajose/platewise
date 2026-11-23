import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/app/app.dart';

void main() {
  testWidgets('app shell builds', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PlateWiseApp()));
    expect(find.text('PlateWise'), findsOneWidget);
  });
}
