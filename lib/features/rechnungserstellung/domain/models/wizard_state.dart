import 'package:freezed_annotation/freezed_annotation.dart';

import 'abrechnungs_modus.dart';
import 'vorschau_zeile.dart';
import 'zeitraum_typ.dart';

part 'wizard_state.freezed.dart';

/// Zustand des Rechnungslegung-Wizards.
///
/// Hält alle Einstellungen der fünf Wizard-Schritte sowie die erzeugte
/// Vorschau. Der State wird vom `RechnungslegungWizardNotifier` verwaltet.
@Freezed(toJson: false, fromJson: false)
abstract class WizardState with _$WizardState {
  const factory WizardState({
    /// Aktueller Wizard-Schritt (1–5).
    @Default(1) int schritt,

    /// Abrechnungsmodus (Schritt 1).
    @Default(AbrechnungsModus.zeitperioden) AbrechnungsModus modus,

    /// Ausgewählte Mitglieder (Modi: einzelnesMitglied, ausgewaehlteMitglieder).
    @Default([]) List<int> mitgliedIds,

    /// Ausgewählte Kurse/Leistungen (Modus: kurse).
    @Default([]) List<int> leistungIds,

    /// Art des Abrechnungszeitraums (Schritt 3).
    @Default(ZeitraumTyp.monat) ZeitraumTyp zeitraumTyp,

    /// Jahr des Zeitraums (Monat/Quartal/Jahr).
    @Default(0) int jahr,

    /// Monat des Zeitraums (1–12, bei ZeitraumTyp.monat).
    @Default(0) int monat,

    /// Quartal des Zeitraums (1–4, bei ZeitraumTyp.quartal).
    @Default(1) int quartal,

    /// Startdatum bei ZeitraumTyp.periode.
    DateTime? von,

    /// Enddatum bei ZeitraumTyp.periode.
    DateTime? bis,

    /// Nur Mitglieder mit `vertrag_laufzeit_bis >= heute`.
    @Default(true) bool nurAktiveVertraege,

    /// Nur Mitglieder ohne offene/kontierte Beiträge.
    @Default(false) bool nurOhneOffene,

    /// Zielstatus der neuen Beiträge (`kontiert` oder `offen`).
    @Default('kontiert') String zielStatus,

    /// Optionale Bemerkung für den initialen Status-Verlauf.
    String? bemerkung,

    /// Berechnete Vorschau (Schritt 4).
    @Default([]) List<VorschauZeile> vorschauZeilen,

    /// Ergebnis der letzten Ausführung (Schritt 5).
    @Default(0) int erstelltAnzahl,

    /// Anzahl übersprungener Beiträge bei der letzten Ausführung.
    @Default(0) int uebersprungenAnzahl,

    /// Gesamtbetrag der letzten Ausführung (Brutto).
    @Default(0) double gesamtBetrag,
  }) = _WizardState;

  const WizardState._();

  /// Anzahl der Zeilen, die bei der Ausführung erstellt werden.
  int get zuErstellenAnzahl =>
      vorschauZeilen.where((z) => z.kannErstelltWerden).length;

  /// Summe aller zu erstellenden Beträge (Brutto).
  double get zuErstellenBetrag => vorschauZeilen
      .where((z) => z.kannErstelltWerden)
      .fold(0, (sum, z) => sum + z.betrag);
}
