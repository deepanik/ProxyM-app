import 'package:flutter/material.dart';

class AppTheme {
  // App themes mapped from extension's CSS design tokens in popup.css (lines 1-95).
  static const lightBg = Color(0xFFF0F2F5);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFF7F9FC);
  static const lightAccent = Color(0xFF2563EB);
  static const lightBorder = Color(0xFFE2E7EF);
  static const lightText = Color(0xFF111827);

  // Extension Dark Theme Tokens
  static const darkBg = Color(0xFF0D1117);
  static const darkSurface = Color(0xFF161B22);
  static const darkSurface2 = Color(0xFF1C2230);
  static const darkAccent = Color(0xFF3B82F6);
  static const darkBorder = Color(0xFF273042);
  static const darkText = Color(0xFFF9FAFB);

  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: lightBg,
    colorScheme: const ColorScheme.light(
      primary: lightAccent,
      surface: lightSurface,
      surfaceContainerHighest: lightSurface2,
      onSurface: lightText,
      outline: lightBorder,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightSurface,
      foregroundColor: lightText,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: darkBg,
    colorScheme: const ColorScheme.dark(
      primary: darkAccent,
      surface: darkSurface,
      surfaceContainerHighest: darkSurface2,
      onSurface: darkText,
      outline: darkBorder,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkText,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
