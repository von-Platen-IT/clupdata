import 'package:flutter/material.dart';

/// Canonical background colors for each Beitrag status value.
/// Used in DataGrid row coloring and the status badge in dialogs.
const Map<String, Color> kBeitragStatusColors = {
  'kontiert':  Color(0xFFFFF9C4), // light yellow  — newly created
  'offen':     Color(0xFFFFE0B2), // light orange  — due, pending payment
  'bezahlt':   Color(0xFFC8E6C9), // light green   — fully paid
  'angemahnt': Color(0xFFFFCDD2), // light red     — reminder sent
  'storniert': Color(0xFFEEEEEE), // light grey    — cancelled
  'inkasso':   Color(0xFFF8BBD0), // pink          — handed to collections agency
};

/// Returns the background [Color] for the given [status].
/// Falls back to transparent if the status is unknown.
Color beitragStatusColor(String status) =>
    kBeitragStatusColors[status] ?? Colors.transparent;

/// Returns a readable foreground text color (always dark for pastels).
Color beitragStatusTextColor(String status) => Colors.black87;
