import 'package:flutter_test/flutter_test.dart';

import 'package:clupdata/features/calendar/domain/wochen_utils.dart';

void main() {
  group('kalenderwoche (ISO-8601)', () {
    test('erster Januar kann zur letzten KW des Vorjahres gehören', () {
      // 01.01.2027 ist ein Freitag und liegt in KW 53/2026.
      expect(kalenderwoche(DateTime(2027, 1, 1)), 53);
    });

    test('4. Januar liegt immer in KW 1', () {
      expect(kalenderwoche(DateTime(2026, 1, 4)), 1);
      expect(kalenderwoche(DateTime(2025, 1, 4)), 1);
      expect(kalenderwoche(DateTime(2024, 1, 4)), 1);
    });

    test('bekannte Werte', () {
      expect(kalenderwoche(DateTime(2026, 6, 15)), 25); // Mo 15.06.2026
      expect(kalenderwoche(DateTime(2026, 12, 31)), 53);
    });
  });

  group('wochenImMonat', () {
    test('liefert alle Wochen, die in den Monat fallen', () {
      // Juni 2026: 01.06. ist ein Montag → 5 Wochen (01., 08., 15., 22., 29.)
      final wochen = wochenImMonat(DateTime(2026, 6, 15));
      expect(wochen, hasLength(5));
      expect(wochen.first, DateTime(2026, 6, 1));
    });

    test('Wochen zu Monatsbeginn/ende gehören zu beiden Monaten', () {
      // Mai 2026 endet am 31. (Sonntag); der 01.06. ist Montag.
      final mai = wochenImMonat(DateTime(2026, 5, 10));
      expect(mai.last, DateTime(2026, 5, 25));
    });
  });

  group('monatsraster', () {
    test('liefert vollständige Wochen (7 Tage) mit Montag-Start', () {
      final raster = monatsraster(DateTime(2026, 6, 1));
      for (final woche in raster) {
        expect(woche, hasLength(7));
        expect(woche.first.weekday, DateTime.monday);
      }
      // Juni 2026 hat 30 Tage, beginnt Montag → 5 Wochen.
      expect(raster, hasLength(5));
    });

    test('erste/letzte Woche enthält Nachbarmonats-Tage', () {
      final raster = monatsraster(DateTime(2026, 7, 1));
      // 01.07.2026 ist Mittwoch → erste Woche beginnt 29.06.
      expect(raster.first.first, DateTime(2026, 6, 29));
    });
  });

  group('montagVon', () {
    test('normalisiert beliebige Tage auf den Montag', () {
      expect(montagVon(DateTime(2026, 6, 18)), DateTime(2026, 6, 15)); // Do
      expect(montagVon(DateTime(2026, 6, 15)), DateTime(2026, 6, 15)); // Mo
    });
  });

  group('DST-Sicherheit (Sommerzeit-Umstellung)', () {
    // Am 25.10.2026 endet die Sommerzeit (25-Stunden-Tag). Eine naive
    // Addition von `Duration(days: 7)` verschob den Wochenanfang um einen Tag.
    // (Die DST-Sicherheit von `addiereTage` selbst wird in
    // `test/core/utils/datum_utils_test.dart` geprüft.)
    test('monatsraster Oktober 2026: keine doppelten/verschobenen Tage', () {
      final raster = monatsraster(DateTime(2026, 10, 1));
      expect(raster, hasLength(5));
      // Letzte Woche beginnt am Montag, 26.10.2026 – nicht am 25.10.
      expect(raster.last.first, DateTime(2026, 10, 26));
      expect(raster.last.first.weekday, DateTime.monday);
      expect(raster.last.map((d) => d.day).toList(), [
        26,
        27,
        28,
        29,
        30,
        31,
        1,
      ]);
      // Jede Woche beginnt mit Montag und hat 7 Tage.
      for (final woche in raster) {
        expect(woche, hasLength(7));
        expect(woche.first.weekday, DateTime.monday);
      }
    });

    test('wochenImMonat Oktober 2026: letzter Montag ist der 26.', () {
      final wochen = wochenImMonat(DateTime(2026, 10, 1));
      expect(wochen.last, DateTime(2026, 10, 26));
    });

    test('kalenderwoche über die Zeitumstellung', () {
      expect(kalenderwoche(DateTime(2026, 10, 19)), 43);
      expect(kalenderwoche(DateTime(2026, 10, 26)), 44);
    });
  });
}
