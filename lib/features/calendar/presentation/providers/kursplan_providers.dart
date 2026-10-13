import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/kursplan_repository.dart';
import '../../domain/models/kurs_row_data.dart';
import '../../domain/models/kursplan_row_data.dart';
import '../../domain/models/kursplan_termin_row_data.dart';
import '../../domain/wochen_utils.dart';

part 'kursplan_providers.g.dart';

/// Stream aller Kurse (für Raster, Legende und Dialoge).
@riverpod
Stream<List<KursRowData>> kurseList(Ref ref) {
  final repo = ref.watch(kursplanRepositoryProvider);
  return repo.watchKurse();
}

/// Stream aller Kurspläne.
@riverpod
Stream<List<KursplanRowData>> kursplaeneList(Ref ref) {
  final repo = ref.watch(kursplanRepositoryProvider);
  return repo.watchKursplaene();
}

/// Die aktuell angezeigte Woche (immer ein Montag).
@riverpod
class AktuelleWoche extends _$AktuelleWoche {
  @override
  DateTime build() => montagVon(DateTime.now());

  /// Eine Woche vor.
  void vor() => state = state.add(const Duration(days: 7));

  /// Eine Woche zurück.
  void zurueck() => state = state.subtract(const Duration(days: 7));

  /// Zur aktuellen Woche springen.
  void heute() => state = montagVon(DateTime.now());

  /// Direkte Auswahl eines Datums (wird auf Montag normalisiert).
  void setze(DateTime datum) => state = montagVon(datum);
}

/// Alle für die [aktuelleWocheProvider] gültigen Kurspläne.
@riverpod
Future<List<KursplanRowData>> gueltigeKursplaene(Ref ref) async {
  final woche = ref.watch(aktuelleWocheProvider);
  final repo = ref.watch(kursplanRepositoryProvider);
  return repo.loadGueltigePlaene(woche);
}

/// ID des manuell gewählten Kursplans; `0` = automatisch erster gültiger.
@riverpod
class GewaehlterKursplan extends _$GewaehlterKursplan {
  @override
  int build() => 0;

  /// Wählt einen Plan manuell aus (`null` = Automatik).
  void setze(int? id) => state = id ?? 0;

  /// Setzt auf Automatik zurück.
  void reset() => state = 0;
}

/// Termine des für die aktuelle Woche gültigen bzw. gewählten Kursplans.
@riverpod
Future<List<KursplanTerminRowData>> kursplanTermine(Ref ref) async {
  final plaene = await ref.watch(gueltigeKursplaeneProvider.future);
  if (plaene.isEmpty) return [];

  final gewaehlt = ref.watch(gewaehlterKursplanProvider);
  final plan = gewaehlt == 0
      ? plaene.first
      : plaene.firstWhere((p) => p.id == gewaehlt, orElse: () => plaene.first);

  final repo = ref.watch(kursplanRepositoryProvider);
  return repo.loadTermine(plan.id);
}
