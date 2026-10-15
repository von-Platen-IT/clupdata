/// Reine Layout-Logik für die Kursplan-Darstellung (Wochen-/Tagesansicht).
///
/// Die Funktionen sind bewusst frei von Flutter-Abhängigkeiten, damit sie
/// ohne Widget-Test abgesichert werden können. Siehe
/// `plans/kursplan-ueberlappung.md` und `ADR-007`.
library;

import 'models/kursplan_termin_row_data.dart';

/// Platzierung eines Termins im Zeit-Raster.
///
/// [laneIndex] ist die 0-basierte Spur innerhalb des Überlappungs-Clusters,
/// [laneAnzahl] die Anzahl der Spuren dieses Clusters (bestimmt die Breite),
/// [parallelAnzahl] die Anzahl der Termine, die sich mit diesem zeitlich
/// tatsächlich überlappen (inklusive diesem selbst).
class TerminPlatzierung {
  const TerminPlatzierung({
    required this.termin,
    required this.laneIndex,
    required this.laneAnzahl,
    required this.parallelAnzahl,
  });

  /// Der platzierte Termin.
  final KursplanTerminRowData termin;

  /// 0-basierte Spur innerhalb des Clusters.
  final int laneIndex;

  /// Anzahl der Spuren im Cluster (≥ 1).
  final int laneAnzahl;

  /// Anzahl der Termine mit echtem Zeit-Overlap (inkl. diesem, ≥ 1).
  final int parallelAnzahl;

  /// True, wenn dieser Termin gleichzeitig mit mindestens einem anderen läuft.
  bool get istParallel => parallelAnzahl > 1;
}

/// True, wenn sich [a] und [b] zeitlich überlappen.
///
/// Berührung (Ende == Start) gilt **nicht** als Überlappung.
bool ueberlappt(KursplanTerminRowData a, KursplanTerminRowData b) {
  return a.startMinuten < b.endMinuten && b.startMinuten < a.endMinuten;
}

/// Verteilt [termine] per Greedy-Intervall-Partitionierung auf Spuren.
///
/// Termine werden nach Startzeit sortiert und in **Überlappungs-Cluster**
/// (transitiv verbundene Intervalle) gruppiert. Innerhalb eines Clusters
/// erhält jeder Termin die erste Spur, deren letzter Termin vor seiner
/// Startzeit endet; andernfalls wird eine neue Spur angelegt. Die Breite
/// ergibt sich aus der Spurenzahl des jeweiligen Clusters – nicht überlappende
/// Termine teilen sich eine Spur und nutzen die volle Breite.
List<TerminPlatzierung> berechnePlatzierungen(
  List<KursplanTerminRowData> termine,
) {
  if (termine.isEmpty) return <TerminPlatzierung>[];

  final sortiert = [...termine]
    ..sort((a, b) {
      final cmp = a.startMinuten.compareTo(b.startMinuten);
      if (cmp != 0) return cmp;
      return a.endMinuten.compareTo(b.endMinuten);
    });

  final ergebnis = <TerminPlatzierung>[];
  var clusterStart = 0;
  var clusterEnde = -1;

  for (var i = 0; i < sortiert.length; i++) {
    final t = sortiert[i];
    if (i > 0 && t.startMinuten >= clusterEnde) {
      ergebnis.addAll(_platziereCluster(sortiert.sublist(clusterStart, i)));
      clusterStart = i;
      clusterEnde = -1;
    }
    if (t.endMinuten > clusterEnde) clusterEnde = t.endMinuten;
  }
  ergebnis.addAll(_platziereCluster(sortiert.sublist(clusterStart)));
  return ergebnis;
}

/// Liefert die IDs der Kurse, die im übergebenen Termin-Set parallel laufen.
///
/// Zwei Termine gelten als parallel, wenn sie sich zeitlich überlappen und zu
/// **unterschiedlichen** Kursen gehören.
Set<int> paralleleKursIds(List<KursplanTerminRowData> termine) {
  final ids = <int>{};
  for (var i = 0; i < termine.length; i++) {
    for (var j = i + 1; j < termine.length; j++) {
      if (termine[i].kursId != termine[j].kursId &&
          ueberlappt(termine[i], termine[j])) {
        ids
          ..add(termine[i].kursId)
          ..add(termine[j].kursId);
      }
    }
  }
  return ids;
}

/// Platziert die Termine eines Clusters auf Spuren.
List<TerminPlatzierung> _platziereCluster(
  List<KursplanTerminRowData> cluster,
) {
  final laneEnden = <int>[];
  final lanes = <int>[];

  for (final t in cluster) {
    var lane = -1;
    for (var i = 0; i < laneEnden.length; i++) {
      if (laneEnden[i] <= t.startMinuten) {
        lane = i;
        break;
      }
    }
    if (lane == -1) {
      lane = laneEnden.length;
      laneEnden.add(t.endMinuten);
    } else {
      laneEnden[lane] = t.endMinuten;
    }
    lanes.add(lane);
  }

  final laneAnzahl = laneEnden.length;
  return [
    for (var i = 0; i < cluster.length; i++)
      TerminPlatzierung(
        termin: cluster[i],
        laneIndex: lanes[i],
        laneAnzahl: laneAnzahl,
        parallelAnzahl: _parallelAnzahl(cluster[i], cluster),
      ),
  ];
}

/// Anzahl der Termine im Cluster, die sich mit [termin] überlappen (inkl. ihm).
int _parallelAnzahl(
  KursplanTerminRowData termin,
  List<KursplanTerminRowData> cluster,
) {
  var count = 1;
  for (final other in cluster) {
    if (identical(other, termin)) continue;
    if (ueberlappt(termin, other)) count++;
  }
  return count;
}
