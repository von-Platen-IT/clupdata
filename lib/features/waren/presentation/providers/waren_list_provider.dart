import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/waren_row_data.dart';
import '../../data/waren_repository.dart';
import '../../../stammdaten/data/stammdaten_repository.dart';

part 'waren_list_provider.g.dart';

@riverpod
Stream<List<WarenDetail>> watchWarenDetails(Ref ref) {
  return ref.watch(warenRepositoryProvider).watchWarenDetails();
}

@riverpod
Stream<Map<String, String>> stammdatenSettingsMapForWaren(Ref ref) {
  return ref.watch(stammdatenRepositoryProvider).watchSettings().map((settings) {
    return {for (var s in settings) s.schluessel: s.wert ?? ''};
  });
}

@riverpod
AsyncValue<List<WarenRowData>> warenGridRows(Ref ref) {
  final detailsAsync = ref.watch(watchWarenDetailsProvider);
  final settingsAsync = ref.watch(stammdatenSettingsMapForWarenProvider);

  if (detailsAsync.isLoading || settingsAsync.isLoading) {
    return const AsyncValue.loading();
  }
  
  if (detailsAsync.hasError) {
    return AsyncValue.error(detailsAsync.error!, detailsAsync.stackTrace!);
  }
  
  if (settingsAsync.hasError) {
    return AsyncValue.error(settingsAsync.error!, settingsAsync.stackTrace!);
  }

  final details = detailsAsync.value ?? [];
  final settings = settingsAsync.value ?? {};

  final mwstKey = settings['mwst_aktiv_schluessel'] ?? 'mwst_standard';
  final mwstValueStr = settings[mwstKey] ?? '19';
  final mwstRate = double.tryParse(mwstValueStr) ?? 19.0;

  final rows = details.map((d) {
    final mwstMultiplier = 1 + (mwstRate / 100);
    // Bruttopreis is stored, Netto is computed.
    final brutto = d.ware.bruttopreis;
    final netto = brutto / mwstMultiplier;

    return WarenRowData(
      id: d.ware.id,
      bezeichnung: d.ware.bezeichnung,
      beschreibung: d.ware.beschreibung,
      kategorie: d.ware.kategorie,
      groesse: d.ware.groesse,
      farbe: d.ware.farbe,
      geschlecht: d.ware.geschlecht,
      material: d.ware.material,
      einkaufspreis: d.ware.einkaufspreis,
      bruttopreis: brutto,
      nettopreis: netto,
      bestand: d.ware.bestand,
      mindestbestand: d.ware.mindestbestand,
      lieferant: d.ware.lieferant,
      hersteller: d.ware.hersteller,
      herstellerArtikelnr: d.ware.herstellerArtikelnr,
      gewichtKg: d.ware.gewichtKg,
      einheit: d.ware.einheit,
      bildUrl: d.ware.bildUrl,
      aktiv: d.ware.aktiv,
      erstelltAm: d.ware.erstelltAm,
      aktualisiertAm: d.ware.aktualisiertAm,
      bemerkungId: d.bemerkung?.id,
    );
  }).toList();

  return AsyncValue.data(rows);
}
