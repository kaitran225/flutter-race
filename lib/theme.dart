import 'package:flutter/material.dart';

/// Shared palette so every screen looks like the same product.
class AppTheme {
  static const Color seed = Color(0xFF5B2A86);
  static const Color trackColor = Color(0xFF241B33);
  static const Color laneColor = Color(0xFF2F2440);
  static const Color laneAltColor = Color(0xFF362A4A);
  static const Color winColor = Color(0xFF2E7D32);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF6F4FA),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        centerTitle: true,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        elevation: 2,
      ),
    );
  }
}

/// Lane colours alternate slightly so the four lanes stay readable.
Color laneBackground(int index) =>
    index.isEven ? AppTheme.laneColor : AppTheme.laneAltColor;
