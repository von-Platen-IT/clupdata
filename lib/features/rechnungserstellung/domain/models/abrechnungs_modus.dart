/// Abrechnungsmodus des Rechnungslegung-Wizards.
///
/// Definiert, welcher Empfängerkreis abgerechnet wird. Der Zeitraum wird
/// in jedem Modus abgefragt (siehe `wizard_state.dart`).
enum AbrechnungsModus {
  zeitperioden(
    'Nach Zeitperioden',
    'Alle Mitglieder mit gültigem Vertrag für einen Zeitraum',
  ),
  einzelnesMitglied(
    'Nach einem einzelnen Mitglied',
    'Offene Perioden eines Mitglieds abarbeiten',
  ),
  ausgewaehlteMitglieder(
    'Nach ausgewählten Mitgliedern',
    'Bestimmte Mitglieder gezielt auswählen',
  ),
  kurse('Nach Kursen', 'Alle Mitglieder bestimmter Kurse/Vertragsarten');

  const AbrechnungsModus(this.label, this.description);

  /// Anzeigename im Wizard (Schritt 1).
  final String label;

  /// Kurzbeschreibung unter dem Modus-Namen.
  final String description;
}
