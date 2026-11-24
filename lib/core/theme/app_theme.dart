import 'package:flutter/material.dart';

class AppTheme {
  static const Color acceptRegionColor = Color(0xFF0D9488); // Teal
  static const Color rejectTailColor = Color(0xFFE11D48); // Crimson/Rose

  static ThemeData get lightTheme {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1E3A8A),
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      appBarTheme: AppBarTheme(
        backgroundColor: base.surface,
        foregroundColor: base.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: base.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF111111),
          surfaceContainerLowest: const Color(0xFF0D0D0D),
          surfaceContainerLow: const Color(0xFF161616),
          surfaceContainer: const Color(0xFF1B1B1B),
          surfaceContainerHigh: const Color(0xFF222222),
          surfaceContainerHighest: const Color(0xFF2A2A2A),
          outline: const Color(0xFF444444),
          outlineVariant: const Color(0xFF2A2A2A),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: base.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: base.surface,
        foregroundColor: base.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: base.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: base.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: base.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: base.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}
