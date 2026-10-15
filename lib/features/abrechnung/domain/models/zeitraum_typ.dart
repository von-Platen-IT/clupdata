/// Art des Abrechnungszeitraums im Abrechnungslauf (Schritt 1).
enum ZeitraumTyp {
  monat('Monat'),
  quartal('Quartal'),
  jahr('Jahr'),
  periode('Zeitraum von–bis');

  const ZeitraumTyp(this.label);

  /// Anzeigename im Radio-Button der Zeitraum-Auswahl.
  final String label;
}
