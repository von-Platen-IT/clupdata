import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/utils/datum_utils.dart';
import '../../data/kursplan_repository.dart';
import '../../domain/models/kurs_row_data.dart';
import '../../domain/models/kursplan_ansicht.dart';
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

/// Alle für die Woche des aktuellen Fokus-Datums gültigen Kurspläne.
///
/// Der Fokus stammt aus der [KursplanAnsichtSteuerung] (Ansicht unabhängig).
@riverpod
Future<List<KursplanRowData>> gueltigeKursplaene(Ref ref) async {
  final fokus = ref.watch(kursplanAnsichtSteuerungProvider).fokus;
  final woche = montagVon(fokus);
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

/// Unveränderlicher Zustand der Kursplan-Darstellung (Ansicht + Fokus-Datum).
class KursplanAnsichtZustand {
  const KursplanAnsichtZustand({required this.fokus, required this.ansicht});

  /// Das Datum, auf das die Darstellung ausgerichtet ist (Jahr/Monat/Woche/Tag).
  final DateTime fokus;

  /// Aktive Darstellungsform.
  final KursplanAnsicht ansicht;

  KursplanAnsichtZustand copyWith({DateTime? fokus, KursplanAnsicht? ansicht}) {
    return KursplanAnsichtZustand(
      fokus: fokus ?? this.fokus,
      ansicht: ansicht ?? this.ansicht,
    );
  }
}

/// Steuerung der Kursplan-Darstellung (Ansicht + Navigation).
///
/// Initial: **aktuelle Wochenansicht** (Anforderung). Die Navigation bewegt
/// den [KursplanAnsichtZustand.fokus] in Schritten der aktiven Ansicht.
@riverpod
class KursplanAnsichtSteuerung extends _$KursplanAnsichtSteuerung {
  @override
  KursplanAnsichtZustand build() => KursplanAnsichtZustand(
    fokus: DateTime.now(),
    ansicht: KursplanAnsicht.woche,
  );

  /// Wechselt die Darstellungsform (Fokus bleibt erhalten).
  void setzeAnsicht(KursplanAnsicht ansicht) {
    state = state.copyWith(ansicht: ansicht);
  }

  /// Springt zum angegebenen Datum (DatePicker).
  void setzeFokus(DateTime datum) {
    state = state.copyWith(fokus: datum);
  }

  /// Springt zum heutigen Tag.
  void heute() => state = state.copyWith(fokus: DateTime.now());

  /// Navigation „vor" in Schritten der aktiven Ansicht.
  void vor() => state = state.copyWith(fokus: _verschiebe(1));

  /// Navigation „zurück" in Schritten der aktiven Ansicht.
  void zurueck() => state = state.copyWith(fokus: _verschiebe(-1));

  DateTime _verschiebe(int richtung) {
    final f = state.fokus;
    switch (state.ansicht) {
      case KursplanAnsicht.jahr:
        return DateTime(f.year + richtung, f.month, f.day);
      case KursplanAnsicht.monat:
        return DateTime(f.year, f.month + richtung, f.day);
      case KursplanAnsicht.woche:
        return addiereTage(f, 7 * richtung);
      case KursplanAnsicht.tag:
        return addiereTage(f, richtung);
    }
  }
}
