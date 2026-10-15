/// Darstellungsform des Kursplans (wie im Google Kalender).
enum KursplanAnsicht {
  jahr('Jahr'),
  monat('Monat'),
  woche('Woche'),
  tag('Tag');

  const KursplanAnsicht(this.label);

  /// Anzeigename im Ansichts-Dropdown.
  final String label;
}
