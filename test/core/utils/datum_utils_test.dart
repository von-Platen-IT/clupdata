import 'package:flutter_test/flutter_test.dart';

import 'package:clupdata/core/utils/datum_utils.dart';

void main() {
  group('addiereTage', () {
    test('addiert Kalendertage DST-sicher über die Zeitumstellung', () {
      // Sommerzeit-Ende 25.10.2026 (25-Stunden-Tag).
      expect(addiereTage(DateTime(2026, 10, 19), 7), DateTime(2026, 10, 26));
      // Sommerzeit-Beginn 29.03.2026 (23-Stunden-Tag).
      expect(addiereTage(DateTime(2026, 3, 23), 7), DateTime(2026, 3, 30));
    });

    test('behält die Uhrzeit bei', () {
      expect(
        addiereTage(DateTime(2026, 10, 19, 14, 30), 7),
        DateTime(2026, 10, 26, 14, 30),
      );
    });

    test('negative Tage und Monatswechsel', () {
      expect(addiereTage(DateTime(2026, 10, 26), -7), DateTime(2026, 10, 19));
      expect(addiereTage(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 1));
    });
  });

  group('differenzInTagen', () {
    test('liefert ganze Kalendertage DST-sicher', () {
      expect(
        differenzInTagen(DateTime(2026, 10, 19), DateTime(2026, 10, 26)),
        7,
      );
      // Über die Zeitumstellung hinweg exakt 7 Tage.
      expect(
        differenzInTagen(DateTime(2026, 10, 24), DateTime(2026, 10, 31)),
        7,
      );
    });

    test('ignoriert die Uhrzeit', () {
      expect(
        differenzInTagen(
          DateTime(2026, 10, 19, 23, 59),
          DateTime(2026, 10, 20, 0, 1),
        ),
        1,
      );
    });

    test('negativ, wenn bis vor von liegt', () {
      expect(
        differenzInTagen(DateTime(2026, 10, 26), DateTime(2026, 10, 19)),
        -7,
      );
    });
  });
}
