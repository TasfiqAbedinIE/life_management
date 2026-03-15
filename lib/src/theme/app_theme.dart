import 'package:flutter/material.dart';

class AppTheme {
  // Theme + Font Notifiers
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  static final ValueNotifier<String> fontFamily = ValueNotifier<String>(
    'Delius',
  ); // default

  static ThemeData lightTheme(String font) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF4F7FB),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF4F7FB),
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
      fontFamily: font,
    );
  }

  static ThemeData darkTheme(String font) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C9BFF),
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF09111F),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF09111F),
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF121C2E),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF121C2E),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF172338),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
      fontFamily: font,
    );
  }
}

class AppPalette {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? const Color(0xFF09111F) : const Color(0xFFF4F7FB);

  static Color backgroundAccent(BuildContext context) =>
      isDark(context) ? const Color(0xFF101B31) : const Color(0xFFE8EEFF);

  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF121C2E) : Colors.white;

  static Color surfaceAlt(BuildContext context) =>
      isDark(context) ? const Color(0xFF172338) : const Color(0xFFF7F9FC);

  static Color border(BuildContext context) => isDark(context)
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFFDCE4F2);

  static Color mutedText(BuildContext context) => isDark(context)
      ? const Color(0xFF9FB0CC)
      : const Color(0xFF5F6F89);

  static Color softShadow(BuildContext context) => isDark(context)
      ? Colors.black.withValues(alpha: 0.32)
      : Colors.black.withValues(alpha: 0.08);

  static List<Color> heroGradient(BuildContext context) => isDark(context)
      ? const [Color(0xFF243B6B), Color(0xFF111A33)]
      : const [Color(0xFF4F62D8), Color(0xFF1E2E78)];

  static List<Color> quoteGradient(BuildContext context) => isDark(context)
      ? const [Color(0xFF16233E), Color(0xFF1B3153)]
      : const [Color(0xFFEEF2FF), Color(0xFFE0E7FF)];
}
