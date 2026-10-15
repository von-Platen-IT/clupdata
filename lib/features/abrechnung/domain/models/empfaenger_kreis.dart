/// Empfängerkreis des Abrechnungslaufs (Schritt 1, Chip-Leiste).
///
/// Ersetzt die früheren vier Modi als kompakte Auswahl – der Standardfall
/// „Alle Mitglieder" ist vorausgewählt (2-Klick-Workflow).
enum EmpfaengerKreis {
  alleMitglieder(
    'Alle Mitglieder',
    'Alle Mitglieder mit gültigem Vertrag für den Zeitraum',
  ),
  kurse('Nach Kursen', 'Alle Mitglieder bestimmter Kurse/Vertragsarten'),
  mitglieder('Mitglieder wählen', 'Bestimmte Mitglieder gezielt auswählen'),
  einzelnesMitglied('Einzelnes Mitglied', 'Offene Perioden eines Mitglieds');

  const EmpfaengerKreis(this.label, this.description);

  /// Anzeigename im Chip.
  final String label;

  /// Kurzbeschreibung unter der Auswahl.
  final String description;
}
