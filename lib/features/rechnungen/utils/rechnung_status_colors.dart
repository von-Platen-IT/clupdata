import 'package:flutter/material.dart';

/// Canonical background colors for each Rechnung status value.
/// Used in DataGrid row coloring and the status badge in dialogs.
const Map<String, Color> kRechnungStatusColors = {
  'offen': Color(0xFFFFCDD2), // light red — pending payment
  'bezahlt': Color(0xFFC8E6C9), // light green — fully paid
  'storniert': Color(0xFFFFE0B2), // light orange — cancelled
};

/// Returns the background [Color] for the given [status].
/// Falls back to transparent if the status is unknown.
Color rechnungStatusColor(String status) =>
    kRechnungStatusColors[status] ?? Colors.transparent;

/// Returns a readable foreground text color (always dark for pastels).
Color rechnungStatusTextColor(String status) => Colors.black87;
