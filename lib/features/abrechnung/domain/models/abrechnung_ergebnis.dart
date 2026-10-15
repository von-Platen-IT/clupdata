/// Ergebnis eines ausgeführten Abrechnungslaufs (Schritt 4).
class AbrechnungErgebnis {
  const AbrechnungErgebnis({
    required this.erstelltAnzahl,
    required this.uebersprungenAnzahl,
    required this.gesamtBetrag,
    required this.fehler,
    this.erstellteNummern = const [],
  });

  /// Anzahl der erstellten Beiträge.
  final int erstelltAnzahl;

  /// Anzahl übersprungener Zeilen (bereits abgerechnet / nicht ausgewählt).
  final int uebersprungenAnzahl;

  /// Summe der erstellten Beträge (Brutto).
  final double gesamtBetrag;

  /// Fehlermeldungen (Zeilen, die nicht erstellt werden konnten).
  final List<String> fehler;

  /// Rechnungsnummern der erstellten Beiträge (für Anschlussaktionen).
  final List<String> erstellteNummern;

  bool get erfolgreich => fehler.isEmpty;
}
