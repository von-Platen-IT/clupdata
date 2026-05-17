import 'package:flutter/material.dart';

/// Common interface for status enums used across features (Beiträge, Rechnungen).
///
/// This interface ensures consistent status handling for:
/// - Status label display
/// - Status color coding (background and text)
/// - Status dropdown options
/// - Status badge rendering via [StatusBadge]
///
/// All status enums that implement this interface must provide:
/// - A [value] for database storage
/// - A [label] for human-readable display
/// - [backgroundColor] and [textColor] for consistent visual styling
///
/// See also: [BeitragStatus], [RechnungStatus]
abstract interface class StatusManager {
  /// The string value stored in the database.
  String get value;

  /// The human-readable label displayed in the UI.
  String get label;

  /// The background color used for status badges and row highlighting.
  Color get backgroundColor;

  /// The foreground/text color used for status badges.
  Color get textColor;

  /// Creates a [StatusManager] from a database string value.
  ///
  /// The [values] parameter should be the list of all enum values
  /// for the concrete status type. Falls back to the first value
  /// if no match is found.
  static T fromString<T extends StatusManager>(
    String value,
    List<T> values,
  ) {
    return values.firstWhere(
      (s) => s.value.toLowerCase() == value.toLowerCase(),
      orElse: () => values.first,
    );
  }

  /// All status values as strings for legacy compatibility with dropdowns.
  static List<String> allStringValues<T extends StatusManager>(
    List<T> values,
  ) {
    return values.map((s) => s.value).toList();
  }
}
