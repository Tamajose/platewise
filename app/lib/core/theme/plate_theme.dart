import 'package:material_ui/material_ui.dart';

abstract final class PlateColors {
  static const canvas = Color(0xFFF5F2E9);
  static const surface = Color(0xFFFFFDF8);
  static const ink = Color(0xFF203329);
  static const muted = Color(0xFF4E6155);
  static const line = Color(0xFFE0DCCF);
  static const forest = Color(0xFF285B44);
  static const deep = Color(0xFF163A2C);
  static const sage = Color(0xFFE7EDD9);
  static const lime = Color(0xFFE0EE9C);
  static const blue = Color(0xFF23586D);
  static const water = Color(0xFFE8F3F6);
  static const amberInk = Color(0xFF714508);
  static const amber = Color(0xFFFFF2D9);
  static const red = Color(0xFF9D302B);
}

ThemeData plateTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: PlateColors.forest).copyWith(
    primary: PlateColors.forest,
    onPrimary: Colors.white,
    primaryContainer: PlateColors.sage,
    onPrimaryContainer: PlateColors.ink,
    surface: PlateColors.surface,
    onSurface: PlateColors.ink,
    onSurfaceVariant: PlateColors.muted,
    outline: PlateColors.muted,
    outlineVariant: PlateColors.line,
    secondary: PlateColors.blue,
    error: PlateColors.red,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: PlateColors.canvas,
  );
  const tabular = [FontFeature.tabularFigures()];
  return base.copyWith(
    textTheme: base.textTheme
        .copyWith(
          displayMedium: const TextStyle(
            fontFamily: 'DM Serif Text',
            fontSize: 54,
            height: 1.02,
            fontWeight: FontWeight.w400,
            letterSpacing: -.8,
          ),
          displaySmall: const TextStyle(
            fontSize: 46,
            height: 1.05,
            fontWeight: FontWeight.w700,
            letterSpacing: -2.3,
            fontFeatures: tabular,
          ),
          headlineLarge: const TextStyle(
            fontFamily: 'DM Serif Text',
            fontSize: 40,
            height: 1.08,
            fontWeight: FontWeight.w400,
            letterSpacing: -.5,
          ),
          headlineMedium: const TextStyle(
            fontFamily: 'DM Serif Text',
            fontSize: 27,
            height: 1.16,
            fontWeight: FontWeight.w400,
          ),
          headlineSmall: const TextStyle(
            fontSize: 23,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: -.6,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            height: 1.25,
            fontWeight: FontWeight.w700,
            letterSpacing: -.35,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.45),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.46),
          bodySmall: const TextStyle(fontSize: 12, height: 1.46),
          labelLarge: const TextStyle(
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(
          bodyColor: PlateColors.ink,
          displayColor: PlateColors.ink,
          fontFamilyFallback: const ['NotoSansBengali'],
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        foregroundColor: PlateColors.forest,
        side: const BorderSide(color: Color(0xFF9DAE9D)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: PlateColors.canvas,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 18,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PlateColors.deep,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PlateColors.surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFA0B3A3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFA0B3A3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: PlateColors.forest, width: 2),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: PlateColors.surface,
      indicatorColor: PlateColors.sage,
      height: 72,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(color: PlateColors.line, space: 1),
  );
}
