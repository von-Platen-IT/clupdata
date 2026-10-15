import 'package:freezed_annotation/freezed_annotation.dart';

import 'empfaenger_kreis.dart';
import 'vorschau_zeile.dart';
import 'zeitraum_typ.dart';

part 'abrechnungslauf_state.freezed.dart';

/// Zustand des Abrechnungslaufs (4-Schritt-Assistent).
///
/// Schritt 1: Empfängerkreis + Zeitraum · Schritt 2: Vorschau (editierbar) ·
/// Schritt 3: Freigabe · Schritt 4: Ergebnis.
@Freezed(toJson: false, fromJson: false)
abstract class AbrechnungslaufState with _$AbrechnungslaufState {
  const factory AbrechnungslaufState({
    /// Aktueller Schritt (1–4).
    @Default(1) int schritt,

    /// Empfängerkreis (Schritt 1, Chip-Leiste).
    @Default(EmpfaengerKreis.alleMitglieder) EmpfaengerKreis kreis,

    /// Ausgewählte Mitglieder (Kreis: mitglieder, einzelnesMitglied).
    @Default([]) List<int> mitgliedIds,

    /// Ausgewählte Kurse/Leistungen (Kreis: kurse).
    @Default([]) List<int> leistungIds,

    /// Art des Abrechnungszeitraums (Schritt 1).
    @Default(ZeitraumTyp.monat) ZeitraumTyp zeitraumTyp,

    /// Jahr des Zeitraums.
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

    /// Zielstatus der neuen Beiträge (`entwurf`, `offen`).
    @Default('offen') String zielStatus,

    /// Zahlungsziel in Tagen (Fälligkeit = Erstellung + Wert).
    @Default(14) int zahlungszielTage,

    /// Bemerkung für den initialen Status-Verlauf (Pflicht bei Erstellung).
    String? bemerkung,

    /// Berechnete Vorschau (Schritt 2).
    @Default([]) List<VorschauZeile> vorschauZeilen,

    /// Ergebnis der letzten Ausführung (Schritt 4).
    @Default(0) int erstelltAnzahl,
    @Default(0) int uebersprungenAnzahl,
    @Default(0) double gesamtBetrag,
    @Default([]) List<String> fehler,
    @Default([]) List<String> erstellteNummern,
  }) = _AbrechnungslaufState;

  const AbrechnungslaufState._();

  /// Anzahl der Zeilen, die bei der Ausführung erstellt werden.
  int get zuErstellenAnzahl =>
      vorschauZeilen.where((z) => z.kannErstelltWerden).length;

  /// Summe aller zu erstellenden Beträge (Brutto).
  double get zuErstellenBetrag => vorschauZeilen
      .where((z) => z.kannErstelltWerden)
      .fold(0, (sum, z) => sum + z.betrag);

  /// Anzahl bereits abgerechneter Zeilen.
  int get bereitsAbgerechnetAnzahl =>
      vorschauZeilen.where((z) => z.bereitsAbgerechnet).length;
}
