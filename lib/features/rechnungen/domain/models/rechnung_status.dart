import 'package:flutter/material.dart';

import '../../../../core/models/status_manager.dart';
import '../../utils/rechnung_status_colors.dart';

/// Enum representing all possible states of a Rechnung (invoice).
/// Implements [StatusManager] for consistent status display across features.
enum RechnungStatus implements StatusManager {
  offen, // Invoice sent, awaiting payment
  bezahlt, // Fully paid
  storniert; // Cancelled

  /// Returns the database string representation.
  @override
  String get value => name;

  /// Creates a [RechnungStatus] from a database string.
  /// Case-insensitive comparison.
  static RechnungStatus fromString(String value) {
    return StatusManager.fromString(value, RechnungStatus.values);
  }

  /// Human-readable label for the status.
  @override
  String get label {
    switch (this) {
      case RechnungStatus.offen:
        return 'Offen';
      case RechnungStatus.bezahlt:
        return 'Bezahlt';
      case RechnungStatus.storniert:
        return 'Storniert';
    }
  }

  /// Background color for status badges and row highlighting.
  ///
  /// Delegates to the central [rechnungStatusColor] function from
  /// [rechnung_status_colors.dart] – the single source of truth.
  @override
  Color get backgroundColor => rechnungStatusColor(value);

  /// Foreground/text color (always dark for pastel backgrounds).
  ///
  /// Delegates to the central [rechnungStatusTextColor] function from
  /// [rechnung_status_colors.dart].
  @override
  Color get textColor => rechnungStatusTextColor(value);

  /// All status values for dropdowns.
  static List<RechnungStatus> get allValues => RechnungStatus.values;

  /// All status values as strings for legacy compatibility.
  static List<String> get allStringValues =>
      StatusManager.allStringValues(RechnungStatus.values);
}