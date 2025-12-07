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
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.light,
      ),
      fontFamily: font,
    );
  }

  static ThemeData darkTheme(String font) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
      fontFamily: font,
    );
  }
}
