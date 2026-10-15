/// Eine Zeile der Abrechnungs-Vorschau (Schritt 2, editierbar).
///
/// Jede Zeile repräsentiert einen zu erstellenden Beitrag für ein Mitglied
/// in einer Periode. Bereits abgerechnete Perioden sind markiert und werden
/// nicht erneut erstellt (Idempotenz).
class VorschauZeile {
  const VorschauZeile({
    required this.mitgliedId,
    required this.mitgliedName,
    required this.leistungId,
    required this.leistungName,
    required this.abrechnungsZeitraum,
    required this.betrag,
    required this.faelligAm,
    this.inkludiert = true,
    this.bereitsAbgerechnet = false,
    this.hinweis,
  });

  final int mitgliedId;
  final String mitgliedName;
  final int leistungId;
  final String leistungName;

  /// Periodenanfang (z.B. 1.6.2026 für Juni 2026).
  final DateTime abrechnungsZeitraum;

  /// Betrag (Brutto) – editierbar in der Vorschau.
  final double betrag;

  /// Fälligkeitsdatum des zu erstellenden Beitrags.
  final DateTime faelligAm;

  /// Ob die Zeile in die Erstellung übernommen wird (Checkbox).
  final bool inkludiert;

  /// True, wenn der Zeitraum bereits abgerechnet wurde.
  final bool bereitsAbgerechnet;

  /// Hinweis (z.B. „abweichender Einzelpreis", „kein Preis hinterlegt").
  final String? hinweis;

  /// True, wenn die Zeile erstellt werden kann.
  bool get kannErstelltWerden => inkludiert && !bereitsAbgerechnet;

  /// Kopie mit geänderten Feldern (editierbare Vorschau).
  VorschauZeile copyWith({
    double? betrag,
    bool? inkludiert,
    String? hinweis,
    DateTime? faelligAm,
  }) {
    return VorschauZeile(
      mitgliedId: mitgliedId,
      mitgliedName: mitgliedName,
      leistungId: leistungId,
      leistungName: leistungName,
      abrechnungsZeitraum: abrechnungsZeitraum,
      betrag: betrag ?? this.betrag,
      faelligAm: faelligAm ?? this.faelligAm,
      inkludiert: inkludiert ?? this.inkludiert,
      bereitsAbgerechnet: bereitsAbgerechnet,
      hinweis: hinweis ?? this.hinweis,
    );
  }
}
