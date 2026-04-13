import 'package:flutter/material.dart';

/// Extension on Color for alpha adjustments.
///
/// Provides a convenient method to create a new color with a specific
/// opacity percentage (0.0 to 1.0), using [withAlpha] for precision.
extension ColorAlphaExtension on Color {
  /// Returns a new color with the given opacity percentage.
  ///
  /// [percent] must be between 0.0 (fully transparent) and 1.0 (fully opaque).
  /// Example: `Colors.red.withOpacityPercent(0.3)` → red at 30% opacity.
  Color withOpacityPercent(double percent) {
    return withAlpha((255 * percent).round());
  }
}
