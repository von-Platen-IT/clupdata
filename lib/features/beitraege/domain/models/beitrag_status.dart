import 'package:flutter/material.dart';

import '../../utils/beitrag_status_colors.dart';

/// Enum representing all possible states of a Beitrag (contribution/invoice).
/// Replaces the string-based status handling with type-safe operations.
enum BeitragStatus {
  kontiert, // Newly created, not yet processed
  offen, // Invoice sent, awaiting payment
  bezahlt, // Fully paid
  angemahnt, // Reminder sent
  storniert, // Cancelled
  inkasso; // Handed to collections agency

  /// Returns the database string representation.
  String get value => name;

  /// Creates a BeitragStatus from a database string.
  static BeitragStatus fromString(String value) {
    return BeitragStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => BeitragStatus.kontiert,
    );
  }

  /// Human-readable label for the status.
  String get label {
    switch (this) {
      case BeitragStatus.kontiert:
        return 'Kontiert';
      case BeitragStatus.offen:
        return 'Offen';
      case BeitragStatus.bezahlt:
        return 'Bezahlt';
      case BeitragStatus.angemahnt:
        return 'Angemahnt';
      case BeitragStatus.storniert:
        return 'Storniert';
      case BeitragStatus.inkasso:
        return 'Inkasso';
    }
  }

  /// Background color for status badges and row highlighting.
  ///
  /// Delegates to the central [beitragStatusColor] function from
  /// [beitrag_status_colors.dart] – the single source of truth.
  Color get backgroundColor => beitragStatusColor(value);

  /// Foreground/text color (always dark for pastel backgrounds).
  ///
  /// Delegates to the central [beitragStatusTextColor] function from
  /// [beitrag_status_colors.dart].
  Color get textColor => beitragStatusTextColor(value);

  /// Whether this status allows editing of the Beitrag.
  bool get isEditable =>
      this != BeitragStatus.bezahlt && this != BeitragStatus.storniert;

  /// Whether this status indicates the invoice is still open/unpaid.
  bool get isOpen =>
      this == BeitragStatus.offen || this == BeitragStatus.angemahnt;

  /// Whether this status indicates the invoice is finalized.
  bool get isFinal =>
      this == BeitragStatus.bezahlt || this == BeitragStatus.storniert;

  /// All status values for dropdowns.
  static List<BeitragStatus> get allValues => BeitragStatus.values;

  /// All status values as strings for legacy compatibility.
  static List<String> get allStringValues =>
      BeitragStatus.values.map((s) => s.value).toList();
}

/// Extension on String for easy conversion.
extension BeitragStatusStringExtension on String {
  BeitragStatus toBeitragStatus() => BeitragStatus.fromString(this);
}
