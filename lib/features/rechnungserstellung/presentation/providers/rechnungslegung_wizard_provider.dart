import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/database_provider.dart';
import '../../domain/models/abrechnungs_modus.dart';
import '../../domain/models/vorschau_zeile.dart';
import '../../domain/models/wizard_state.dart';
import '../../domain/models/zeitraum_typ.dart';
import '../../services/abrechnung_service.dart';

part 'rechnungslegung_wizard_provider.g.dart';

/// Provider for the unified [AbrechnungService].
@riverpod
AbrechnungService abrechnungService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return AbrechnungService(db);
}

/// State notifier for the invoice wizard (all five steps).
///
/// Holds the complete [WizardState] including the calculated preview.
/// The preview is loaded explicitly when entering step 4
/// ([ladeVorschau]) so that user edits in the preview are never
/// overwritten by re-computation.
@riverpod
class RechnungslegungWizard extends _$RechnungslegungWizard {
  @override
  WizardState build() {
    final now = DateTime.now();
    return WizardState(
      jahr: now.year,
      monat: now.month,
      quartal: ((now.month - 1) ~/ 3) + 1,
      von: DateTime(now.year, now.month, 1),
      bis: now,
    );
  }

  /// Sets the current wizard step (1–5).
  void setSchritt(int schritt) => state = state.copyWith(schritt: schritt);

  /// Sets the billing mode (step 1) and resets the dependent selections.
  void setModus(AbrechnungsModus modus) =>
      state = state.copyWith(modus: modus, mitgliedIds: [], leistungIds: []);

  /// Adds/removes a member from the selection (step 2).
  void toggleMitglied(int mitgliedId) {
    final ids = List<int>.from(state.mitgliedIds);
    ids.contains(mitgliedId) ? ids.remove(mitgliedId) : ids.add(mitgliedId);
    state = state.copyWith(mitgliedIds: ids);
  }

  /// Sets the complete member selection (step 2).
  void setMitglieder(List<int> ids) => state = state.copyWith(mitgliedIds: ids);

  /// Adds/removes a course (Leistung) from the selection (step 2).
  void toggleLeistung(int leistungId) {
    final ids = List<int>.from(state.leistungIds);
    ids.contains(leistungId) ? ids.remove(leistungId) : ids.add(leistungId);
    state = state.copyWith(leistungIds: ids);
  }

  /// Sets the period type (step 3).
  void setZeitraumTyp(ZeitraumTyp typ) =>
      state = state.copyWith(zeitraumTyp: typ);

  /// Sets the year of the billing period (step 3).
  void setJahr(int jahr) => state = state.copyWith(jahr: jahr);

  /// Sets the month of the billing period (step 3).
  void setMonat(int monat) => state = state.copyWith(monat: monat);

  /// Sets the quarter of the billing period (step 3).
  void setQuartal(int quartal) => state = state.copyWith(quartal: quartal);

  /// Sets the start date for ZeitraumTyp.periode (step 3).
  void setVon(DateTime von) => state = state.copyWith(von: von);

  /// Sets the end date for ZeitraumTyp.periode (step 3).
  void setBis(DateTime bis) => state = state.copyWith(bis: bis);

  /// Sets the "active contracts only" filter (step 3).
  void setNurAktiveVertraege(bool value) =>
      state = state.copyWith(nurAktiveVertraege: value);

  /// Sets the "without open contributions" filter (step 3).
  void setNurOhneOffene(bool value) =>
      state = state.copyWith(nurOhneOffene: value);

  /// Sets the target status for new contributions (step 3).
  void setZielStatus(String status) =>
      state = state.copyWith(zielStatus: status);

  /// Sets the optional remark for the initial status history entry (step 3).
  void setBemerkung(String? bemerkung) =>
      state = state.copyWith(bemerkung: bemerkung);

  /// Loads the billing preview from the [AbrechnungService] (entering step 4).
  ///
  /// Called once when the user confirms step 3 – user edits made in the
  /// preview (step 4) are preserved until this method is called again.
  Future<void> ladeVorschau() async {
    final service = ref.read(abrechnungServiceProvider);
    final zeilen = await service.loadVorschau(state);
    state = state.copyWith(vorschauZeilen: zeilen, schritt: 4);
  }

  /// Includes/excludes a single preview row (step 4).
  void toggleZeile(int index) {
    final zeilen = List<VorschauZeile>.from(state.vorschauZeilen);
    final zeile = zeilen[index];
    zeilen[index] = zeile.copyWith(inkludiert: !zeile.inkludiert);
    state = state.copyWith(vorschauZeilen: zeilen);
  }

  /// Updates the (user-overridable) amount of a preview row (step 4).
  void setZeileBetrag(int index, double betrag) {
    final zeilen = List<VorschauZeile>.from(state.vorschauZeilen);
    zeilen[index] = zeilen[index].copyWith(betrag: betrag);
    state = state.copyWith(vorschauZeilen: zeilen);
  }

  /// Executes the creation of all included preview rows (step 4 → 5).
  ///
  /// Returns the number of successfully created contributions.
  Future<int> fuehreAus() async {
    final service = ref.read(abrechnungServiceProvider);
    final result = await service.execute(state.vorschauZeilen, state);
    state = state.copyWith(
      schritt: 5,
      erstelltAnzahl: result.successCount,
      uebersprungenAnzahl: result.skippedCount,
      gesamtBetrag: result.gesamtBetragBrutto,
    );
    return result.successCount;
  }

  /// Resets the wizard to its initial state (start over from step 5).
  void reset() {
    final now = DateTime.now();
    state = WizardState(
      jahr: now.year,
      monat: now.month,
      quartal: ((now.month - 1) ~/ 3) + 1,
      von: DateTime(now.year, now.month, 1),
      bis: now,
    );
  }
}
