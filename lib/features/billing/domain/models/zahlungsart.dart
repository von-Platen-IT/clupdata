/// Zahlungsart eines Zahlungseingangs.
enum Zahlungsart {
  bar('Bar'),
  karte('Karte'),
  lastschrift('Lastschrift'),
  ueberweisung('Überweisung'),
  sonstiges('Sonstiges');

  const Zahlungsart(this.label);

  /// Anzeigename in UI-Dropdowns.
  final String label;

  /// Wandelt einen DB-String in einen Enum-Wert um (Fallback: [sonstiges]).
  static Zahlungsart fromDb(String value) {
    return Zahlungsart.values.firstWhere(
      (z) => z.name == value,
      orElse: () => Zahlungsart.sonstiges,
    );
  }
}
