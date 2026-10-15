import 'package:flutter_test/flutter_test.dart';

import 'package:clupdata/features/calendar/domain/kursplan_layout.dart';
import 'package:clupdata/features/calendar/domain/models/kursplan_termin_row_data.dart';

/// Erzeugt einen Test-Termin mit sinnvollen Defaults.
KursplanTerminRowData termin({
  int id = 1,
  int kursId = 1,
  String kursName = 'Boxen',
  int wochentag = 1,
  required String startzeit,
  String? endezeit,
}) {
  return KursplanTerminRowData(
    id: id,
    kursplanId: 1,
    kursId: kursId,
    kursName: kursName,
    kampfsportart: 'Boxen',
    farbe: '#FFCDD2',
    wochentag: wochentag,
    startzeit: startzeit,
    endezeit: endezeit,
  );
}

void main() {
  group('ueberlappt', () {
    test('erkennt echte Überlappung (symmetrisch)', () {
      final a = termin(startzeit: '16:00', endezeit: '18:00');
      final b = termin(startzeit: '17:00', endezeit: '19:00');
      expect(ueberlappt(a, b), isTrue);
      expect(ueberlappt(b, a), isTrue);
    });

    test('Berührung (Ende == Start) ist keine Überlappung', () {
      final a = termin(startzeit: '16:00', endezeit: '17:00');
      final b = termin(startzeit: '17:00', endezeit: '18:00');
      expect(ueberlappt(a, b), isFalse);
    });

    test('offenes Ende nutzt 60-Minuten-Standarddauer', () {
      final a = termin(startzeit: '16:00'); // endet 17:00
      final b = termin(startzeit: '16:30', endezeit: '17:30');
      expect(ueberlappt(a, b), isTrue);
    });
  });

  group('berechnePlatzierungen', () {
    test('leere Liste liefert leeres Ergebnis', () {
      expect(berechnePlatzierungen([]), isEmpty);
    });

    test('sequenzielle Termine teilen sich eine Spur', () {
      final ergebnis = berechnePlatzierungen([
        termin(id: 1, startzeit: '16:00', endezeit: '17:00'),
        termin(id: 2, startzeit: '17:00', endezeit: '18:00'),
        termin(id: 3, startzeit: '18:00', endezeit: '19:00'),
      ]);
      expect(ergebnis, hasLength(3));
      expect(ergebnis.every((p) => p.laneAnzahl == 1), isTrue);
      expect(ergebnis.every((p) => p.laneIndex == 0), isTrue);
      expect(ergebnis.every((p) => p.istParallel), isFalse);
    });

    test('zwei gleichzeitige Termine erhalten zwei Spuren', () {
      final ergebnis = berechnePlatzierungen([
        termin(id: 1, kursId: 1, startzeit: '16:00', endezeit: '18:00'),
        termin(id: 2, kursId: 2, startzeit: '16:00', endezeit: '17:30'),
      ]);
      expect(ergebnis, hasLength(2));
      expect(ergebnis.every((p) => p.laneAnzahl == 2), isTrue);
      expect(ergebnis.map((p) => p.laneIndex).toSet(), {0, 1});
      expect(ergebnis.every((p) => p.istParallel), isTrue);
      expect(ergebnis.every((p) => p.parallelAnzahl == 2), isTrue);
    });

    test('A/B/C: nicht überlappende Termine teilen eine Spur (2 statt 3)', () {
      // A 16–18, B 17–19, C 18:30–20 → A und C überlappen nicht.
      final ergebnis = berechnePlatzierungen([
        termin(id: 1, startzeit: '16:00', endezeit: '18:00'),
        termin(id: 2, startzeit: '17:00', endezeit: '19:00'),
        termin(id: 3, startzeit: '18:30', endezeit: '20:00'),
      ]);
      expect(ergebnis.every((p) => p.laneAnzahl == 2), isTrue);
      final a = ergebnis.firstWhere((p) => p.termin.id == 1);
      final c = ergebnis.firstWhere((p) => p.termin.id == 3);
      expect(a.laneIndex, c.laneIndex); // teilen sich eine Spur
      expect(a.parallelAnzahl, 2); // nur B
      expect(c.parallelAnzahl, 2); // nur B
    });

    test('getrennte Cluster haben unabhängige Spurenzahlen', () {
      final ergebnis = berechnePlatzierungen([
        termin(id: 1, startzeit: '16:00', endezeit: '17:00'),
        termin(id: 2, startzeit: '16:00', endezeit: '17:00'),
        termin(id: 3, startzeit: '19:00', endezeit: '20:00'),
      ]);
      final cluster1 = ergebnis.where((p) => p.termin.id <= 2);
      final cluster2 = ergebnis.where((p) => p.termin.id == 3);
      expect(cluster1.every((p) => p.laneAnzahl == 2), isTrue);
      expect(cluster2.every((p) => p.laneAnzahl == 1), isTrue);
    });
  });

  group('paralleleKursIds', () {
    test('liefert nur Kurse mit echtem Overlap', () {
      final ids = paralleleKursIds([
        termin(id: 1, kursId: 10, startzeit: '16:00', endezeit: '18:00'),
        termin(id: 2, kursId: 20, startzeit: '17:00', endezeit: '19:00'),
        termin(id: 3, kursId: 30, startzeit: '19:00', endezeit: '20:00'),
      ]);
      expect(ids, {10, 20});
    });

    test('gleicher Kurs zählt nicht als parallel', () {
      final ids = paralleleKursIds([
        termin(id: 1, kursId: 10, startzeit: '16:00', endezeit: '18:00'),
        termin(id: 2, kursId: 10, startzeit: '17:00', endezeit: '19:00'),
      ]);
      expect(ids, isEmpty);
    });
  });
}
