// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'package:flutter/material.dart';

ThemeData hoobirdTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? const Color(0xFFCDBFEA) : const Color(0xFF5B457C),
    onPrimary: dark ? const Color(0xFF24182E) : const Color(0xFFFFFBF7),
    secondary: dark ? const Color(0xFFD7C4A2) : const Color(0xFF8A6A3B),
    onSecondary: dark ? const Color(0xFF24182E) : const Color(0xFFFFFBF7),
    error: dark ? const Color(0xFFFFB4AB) : const Color(0xFF8C2F2F),
    onError: dark ? const Color(0xFF410002) : const Color(0xFFFFFBF7),
    surface: dark ? const Color(0xFF1C1426) : const Color(0xFFF3EBE3),
    onSurface: dark ? const Color(0xFFF6F1EA) : const Color(0xFF24182E),
    surfaceContainerHighest: dark ? const Color(0xFF3A2C4C) : const Color(0xFFFFFBF7),
    onSurfaceVariant: dark ? const Color(0xFFD5CBE0) : const Color(0xFF4A4158),
    outline: dark ? const Color(0xFF8E82A3) : const Color(0xFF6E627C),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerHighest,
      indicatorColor: scheme.primary.withValues(alpha: dark ? 0.28 : 0.18),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? const Color(0xFFCDBFEA) : const Color(0xFFD9CFF0),
        foregroundColor: const Color(0xFF24182E),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
  );
}
