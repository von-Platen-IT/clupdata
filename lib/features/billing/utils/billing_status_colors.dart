import 'package:flutter/material.dart';

/// Zentrale Statusfarben für die Billing-Domäne (Beiträge + Rechnungen).
///
/// Ergänzt [`beitrag_status_colors.dart`](../../../features/beitraege/utils/beitrag_status_colors.dart)
/// und [`rechnung_status_colors.dart`](../../../features/rechnungen/utils/rechnung_status_colors.dart)
/// um die neuen Status-Werte `teilbezahlt` und `entwurf`.
///
/// **NIEMALS Hex-Werte hart codieren** – immer über diese Quelle beziehen.
class BillingStatusColors {
  BillingStatusColors._();

  /// Hellblau – Teilzahlung erhalten, Restforderung offen.
  static const Color teilbezahlt = Color(0xFFBBDEFB);

  /// Hellgrau – Entwurf, noch nicht versendet/kontiert.
  static const Color entwurf = Color(0xFFF5F5F5);

  /// Liefert die Hintergrundfarbe für einen Status-Wert.
  ///
  /// Bekannte Billing-Status werden hier aufgelöst; unbekannte Werte
  /// geben [Colors.transparent] zurück (kein Hardcode-Fallback).
  static Color? forStatus(String status) {
    return switch (status) {
      'teilbezahlt' => teilbezahlt,
      'entwurf' => entwurf,
      _ => null,
    };
  }
}
