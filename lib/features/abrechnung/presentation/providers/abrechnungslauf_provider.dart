import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/abrechnung_service.dart';
import '../../domain/models/abrechnungslauf_state.dart';
import '../../domain/models/empfaenger_kreis.dart';
import '../../domain/models/vorschau_zeile.dart';
import '../../domain/models/zeitraum_typ.dart';

part 'abrechnungslauf_provider.g.dart';

/// Notifier des Abrechnungslaufs (4-Schritt-Assistent).
///
/// Verwaltet den [`AbrechnungslaufState`] und orchestriert Vorschau-Laden
/// sowie die atomare Ausführung über den [`AbrechnungService`].
@riverpod
class Abrechnungslauf extends _$Abrechnungslauf {
  @override
  AbrechnungslaufState build() {
    final now = DateTime.now();
    return AbrechnungslaufState(jahr: now.year, monat: now.month);
  }

  // ── Schritt-Navigation ─────────────────────────────────────────────────

  void naechsterSchritt() {
    if (state.schritt < 4) {
      state = state.copyWith(schritt: state.schritt + 1);
    }
  }

  void vorherigerSchritt() {
    if (state.schritt > 1) {
      state = state.copyWith(schritt: state.schritt - 1);
    }
  }

  // ── Schritt 1: Empfängerkreis & Zeitraum ───────────────────────────────

  void setzeKreis(EmpfaengerKreis kreis) {
    state = state.copyWith(kreis: kreis, mitgliedIds: [], leistungIds: []);
  }

  void toggleMitglied(int mitgliedId) {
    final ids = List<int>.from(state.mitgliedIds);
    ids.contains(mitgliedId) ? ids.remove(mitgliedId) : ids.add(mitgliedId);
    state = state.copyWith(mitgliedIds: ids);
  }

  void toggleLeistung(int leistungId) {
    final ids = List<int>.from(state.leistungIds);
    ids.contains(leistungId) ? ids.remove(leistungId) : ids.add(leistungId);
    state = state.copyWith(leistungIds: ids);
  }

  void setzeZeitraum({
    ZeitraumTyp? zeitraumTyp,
    int? jahr,
    int? monat,
    int? quartal,
    DateTime? von,
    DateTime? bis,
  }) {
    state = state.copyWith(
      zeitraumTyp: zeitraumTyp ?? state.zeitraumTyp,
      jahr: jahr ?? state.jahr,
      monat: monat ?? state.monat,
      quartal: quartal ?? state.quartal,
      von: von ?? state.von,
      bis: bis ?? state.bis,
    );
  }

  // ── Schritt 3: Freigabe-Optionen ───────────────────────────────────────

  void setzeOptionen({
    bool? nurAktiveVertraege,
    bool? nurOhneOffene,
    String? zielStatus,
    int? zahlungszielTage,
    String? bemerkung,
  }) {
    state = state.copyWith(
      nurAktiveVertraege: nurAktiveVertraege ?? state.nurAktiveVertraege,
      nurOhneOffene: nurOhneOffene ?? state.nurOhneOffene,
      zielStatus: zielStatus ?? state.zielStatus,
      zahlungszielTage: zahlungszielTage ?? state.zahlungszielTage,
      bemerkung: bemerkung ?? state.bemerkung,
    );
  }

  // ── Schritt 2: Vorschau ────────────────────────────────────────────────

  /// Lädt die Vorschau aus dem [`AbrechnungService`] (Wechsel zu Schritt 2).
  Future<void> ladeVorschau() async {
    final service = ref.read(abrechnungServiceProvider);
    final zeilen = await service.ladeVorschau(state);
    state = state.copyWith(vorschauZeilen: zeilen, schritt: 2);
  }

  /// Aktualisiert eine Vorschauzeile (Betrag/Auswahl editierbar).
  void aktualisiereZeile(int index, VorschauZeile zeile) {
    final zeilen = List<VorschauZeile>.from(state.vorschauZeilen);
    zeilen[index] = zeile;
    state = state.copyWith(vorschauZeilen: zeilen);
  }

  /// Wählt alle/nur zu erstellende Zeilen aus bzw. ab.
  void setzeAlleAuswahl(bool ausgewaehlt) {
    state = state.copyWith(
      vorschauZeilen: state.vorschauZeilen
          .map(
            (z) => z.bereitsAbgerechnet
                ? z
                : z.copyWith(inkludiert: ausgewaehlt),
          )
          .toList(),
    );
  }

  // ── Schritt 4: Ausführung ──────────────────────────────────────────────

  /// Führt den Abrechnungslauf aus (Wechsel zu Schritt 4).
  Future<void> fuehreAus() async {
    final service = ref.read(abrechnungServiceProvider);
    final ergebnis = await service.fuehreAus(state.vorschauZeilen, state);
    state = state.copyWith(
      schritt: 4,
      erstelltAnzahl: ergebnis.erstelltAnzahl,
      uebersprungenAnzahl: ergebnis.uebersprungenAnzahl,
      gesamtBetrag: ergebnis.gesamtBetrag,
      fehler: ergebnis.fehler,
      erstellteNummern: ergebnis.erstellteNummern,
    );
  }
}
