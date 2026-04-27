import 'package:flutter/material.dart';

/// Canonical background colors for each Beitrag status value.
///
/// This is the **single source of truth** for Beitrag status colors.
/// Used in DataGrid row coloring, status badges, and edit dialogs.
///
/// **NIEMALS** Hex-Werte an anderen Stellen hardcoden – immer diese
/// Konstanten oder die Hilfsfunktionen verwenden.
///
/// Quelle: lib/assets/data/structur.md – Abschnitt 4.2 Screen: Beiträge
const Map<String, Color> kBeitragStatusColors = {
  'kontiert': Color(0xFFFFF9C4), // Hellgelb – neu angelegte Beiträge
  'offen': Color(0xFFFFE0B2), // Hellorange – fällige, ausstehende Zahlungen
  'bezahlt': Color(0xFFC8E6C9), // Hellgrün – vollständig bezahlte Beiträge
  'angemahnt': Color(0xFFFFCDD2), // Hellrot – Zahlungserinnerung versandt
  'storniert': Color(0xFFEEEEEE), // Hellgrau – stornierte Rechnungen
  'inkasso': Color(0xFFF8BBD0), // Pink – an Inkasso übergeben
};

/// Returns the background [Color] for the given Beitrag [status].
/// Falls back to transparent if the status is unknown.
Color beitragStatusColor(String status) =>
    kBeitragStatusColors[status] ?? Colors.transparent;

/// Returns a readable foreground text color (always dark for pastel backgrounds).
Color beitragStatusTextColor(String status) => Colors.black87;
