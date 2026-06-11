import 'package:flutter/material.dart';

/// Defines the global theme settings for the application.
///
/// The `AppTheme` configures Material 3 properties with a focus on desktop usability.
/// It utilizes a compact [VisualDensity] layout to ensure UI elements fit well
/// on computer screens, as opposed to default mobile paddings.
class AppTheme {
  /// Font fallbacks to support Unicode box-drawing characters
  /// (e.g. U+2500 ─) used by PlutoGrid for grid rendering.
  ///
  /// Includes platform-specific system fonts known to contain box-drawing glyphs:
  /// - Windows: Segoe UI, Consolas
  /// - Linux: DejaVu Sans, Noto Sans
  ///
  /// Flutter resolves the first available font from the fallback list,
  /// so all platforms are covered with a single configuration.
  static const _fontFamilyFallback = [
    'Segoe UI',
    'Consolas',
    'DejaVu Sans',
    'Noto Sans',
  ];

  /// Applies font fallbacks to the base text theme for consistent
  /// box-drawing character support across all widgets.
  static TextTheme _withFallbacks(TextTheme base) {
    return base.apply(fontFamilyFallback: _fontFamilyFallback);
  }

  /// Generates the configuration for the light theme mode.
  ///
  /// Uses a deep orange color palette (`colorScheme.fromSeed`) suitable for the Boxclub branding.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepOrange, // Box-Theming: Orange/Rot
        brightness: Brightness.light,
      ),
      // Kompaktere Dichte für Desktop
      visualDensity: VisualDensity.compact,
      textTheme: _withFallbacks(ThemeData.light().textTheme),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      navigationRailTheme: const NavigationRailThemeData(
        useIndicator: true,
        labelType: NavigationRailLabelType.all,
      ),
    );
  }

  /// Generates the configuration for the dark theme mode.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepOrange,
        brightness: Brightness.dark,
      ),
      visualDensity: VisualDensity.compact,
      textTheme: _withFallbacks(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      navigationRailTheme: const NavigationRailThemeData(
        useIndicator: true,
        labelType: NavigationRailLabelType.all,
      ),
    );
  }
}
