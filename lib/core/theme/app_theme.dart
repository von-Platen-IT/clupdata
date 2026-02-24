import 'package:flutter/material.dart';

/// Defines the global theme settings for the application.
///
/// The `AppTheme` configures Material 3 properties with a focus on desktop usability.
/// It utilizes a compact [VisualDensity] layout to ensure UI elements fit well
/// on computer screens, as opposed to default mobile paddings.
class AppTheme {
  
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
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
      ),
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
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        useIndicator: true,
        labelType: NavigationRailLabelType.all,
      ),
    );
  }
}
