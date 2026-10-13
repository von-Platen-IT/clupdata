import 'package:flutter/material.dart';

/// Parst eine Hex-Farbe (`#RRGGBB`) mit Fallback auf Grau.
Color parseKursFarbe(String hex) {
  final bereinigt = hex.replaceAll('#', '');
  final wert = int.tryParse(bereinigt, radix: 16);
  if (wert == null || bereinigt.length != 6) return Colors.grey;
  return Color(0xFF000000 | wert);
}

/// Liefert eine lesbare Vordergrundfarbe für eine Kurs-Hintergrundfarbe.
Color kursTextFarbe(Color hintergrund) =>
    hintergrund.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
