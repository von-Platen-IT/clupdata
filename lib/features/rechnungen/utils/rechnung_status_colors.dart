import 'package:flutter/material.dart';

/// Canonical background colors for each Rechnung status value.
/// Used in DataGrid row coloring and the status badge in dialogs.
///
/// **NIEMALS** Hex-Werte an anderen Stellen hardcoden – immer diese
/// Konstanten oder die Hilfsfunktionen verwenden.
///
/// Quelle: lib/assets/data/structur.md – Abschnitt 4.2 Screen: Rechnungen
const Map<String, Color> kRechnungStatusColors = {
  'offen': Color(0xFFFFE0B2), // Hellorange – ausstehende Zahlung
  'bezahlt': Color(0xFFC8E6C9), // Hellgrün – bezahlte Rechnungen
  'storniert': Color(0xFFEEEEEE), // Hellgrau – stornierte Rechnungen
};

/// Returns the background [Color] for the given Rechnung [status].
/// Falls back to transparent if the status is unknown.
Color rechnungStatusColor(String status) =>
    kRechnungStatusColors[status] ?? Colors.transparent;

/// Returns a readable foreground text color (always dark for pastel backgrounds).
Color rechnungStatusTextColor(String status) => Colors.black87;
