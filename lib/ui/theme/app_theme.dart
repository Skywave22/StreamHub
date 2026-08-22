import 'package:flutter/material.dart';

import '../../core/storage/settings_store.dart';

/// Polished dark/light themes with an adjustable accent color and density.
abstract final class AppTheme {
  static ThemeData _build(Brightness brightness, int accentValue, UiDensity density) {
    final accent = Color(accentValue);
    final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness);
    final isDark = brightness == Brightness.dark;
    final densityValue = density == UiDensity.compact ? VisualDensity.compact : VisualDensity.comfortable;

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: densityValue,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0D0D12) : const Color(0xFFF6F6FA),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF17171F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide.none,
        backgroundColor: scheme.secondaryContainer.withValues(alpha: 0.5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C26) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.35), thickness: 0.6),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    );
  }

  static ThemeData dark(int accent, UiDensity density) => _build(Brightness.dark, accent, density);
  static ThemeData light(int accent, UiDensity density) => _build(Brightness.light, accent, density);

  static ThemeData resolve(ThemePreference pref, int accent, UiDensity density) =>
      pref == ThemePreference.dark ? dark(accent, density) : light(accent, density);
}
