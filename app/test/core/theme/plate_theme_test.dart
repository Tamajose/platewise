import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/core/theme/plate_theme.dart';

double _contrast(Color a, Color b) {
  final hi = a.computeLuminance() > b.computeLuminance() ? a : b;
  final lo = identical(hi, a) ? b : a;
  return (hi.computeLuminance() + 0.05) / (lo.computeLuminance() + 0.05);
}

void main() {
  test('text and surface pairs meet WCAG AA (4.5:1)', () {
    const white = Color(0xFFFFFFFF);
    final pairs = <String, (Color, Color)>{
      'ink on canvas': (PlateColors.ink, PlateColors.canvas),
      'ink on surface': (PlateColors.ink, PlateColors.surface),
      'muted on canvas': (PlateColors.muted, PlateColors.canvas),
      'muted on surface': (PlateColors.muted, PlateColors.surface),
      'forest on sage': (PlateColors.forest, PlateColors.sage),
      'white on forest': (white, PlateColors.forest),
      'white on deep': (white, PlateColors.deep),
      'lime on deep': (PlateColors.lime, PlateColors.deep),
      'blue on water': (PlateColors.blue, PlateColors.water),
      'amber ink on amber': (PlateColors.amberInk, PlateColors.amber),
      'red on white': (PlateColors.red, white),
      'red on surface': (PlateColors.red, PlateColors.surface),
    };
    pairs.forEach((name, pair) {
      expect(
        _contrast(pair.$1, pair.$2),
        greaterThanOrEqualTo(4.5),
        reason: name,
      );
    });
  });

  test('theme uses the warm canvas and the serif display family', () {
    final theme = plateTheme();
    expect(theme.scaffoldBackgroundColor, PlateColors.canvas);
    expect(theme.textTheme.headlineMedium?.fontFamily, 'DM Serif Text');
    expect(theme.textTheme.bodyMedium?.fontFamilyFallback, ['NotoSansBengali']);
  });
}
