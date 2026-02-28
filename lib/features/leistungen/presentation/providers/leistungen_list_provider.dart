import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/leistung_row_data.dart';
import '../../data/leistungen_repository.dart';
import '../../../stammdaten/data/stammdaten_repository.dart';

part 'leistungen_list_provider.g.dart';

@riverpod
Stream<List<LeistungsDetail>> watchLeistungenDetails(Ref ref) {
  return ref.watch(leistungenRepositoryProvider).watchLeistungenDetails();
}

@riverpod
Stream<Map<String, String>> stammdatenSettingsMap(Ref ref) {
  return ref.watch(stammdatenRepositoryProvider).watchSettings().map((settings) {
    return {for (var s in settings) s.schluessel: s.wert ?? ''};
  });
}

@riverpod
AsyncValue<List<LeistungRowData>> leistungenGridRows(Ref ref) {
  final detailsAsync = ref.watch(watchLeistungenDetailsProvider);
  final settingsAsync = ref.watch(stammdatenSettingsMapProvider);

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
    final brutto = d.preis.bruttopreis;
    final netto = brutto / (1 + (mwstRate / 100));

    return LeistungRowData(
      id: d.leistung.id,
      name: d.leistung.name,
      laufzeit: d.leistung.laufzeit,
      preisId: d.preis.id,
      bruttopreis: brutto,
      nettopreis: netto,
      bemerkungId: d.bemerkung?.id,
    );
  }).toList();

  return AsyncValue.data(rows);
}
