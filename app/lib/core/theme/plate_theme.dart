import 'package:material_ui/material_ui.dart';

abstract final class PlateColors {
  static const canvas = Color(0xFFFAFAF7);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF16251D);
  static const muted = Color(0xFF4E6155);
  static const line = Color(0xFFE9EBE6);
  static const forest = Color(0xFF1F6B4F);
  static const deep = Color(0xFF12382A);
  static const sage = Color(0xFFEEF3EE);
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
            fontSize: 46,
            height: 1.05,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.6,
          ),
          displaySmall: const TextStyle(
            fontSize: 46,
            height: 1.05,
            fontWeight: FontWeight.w700,
            letterSpacing: -2.3,
            fontFeatures: tabular,
          ),
          headlineLarge: const TextStyle(
            fontSize: 32,
            height: 1.12,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.1,
          ),
          headlineMedium: const TextStyle(
            fontSize: 21,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: -.5,
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
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        foregroundColor: PlateColors.forest,
        side: const BorderSide(color: Color(0xFFD9DFD8)),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: PlateColors.canvas,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 18,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PlateColors.deep,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PlateColors.surface,
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFA0B3A3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFA0B3A3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PlateColors.forest, width: 2),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: PlateColors.surface,
      indicatorColor: PlateColors.sage,
      indicatorShape: StadiumBorder(),
      height: 70,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: PlateColors.surface,
      indicatorColor: PlateColors.sage,
      indicatorShape: StadiumBorder(),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PlateColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: PlateColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dividerTheme: const DividerThemeData(color: PlateColors.line, space: 1),
  );
}
