import 'package:flutter_test/flutter_test.dart';

import 'package:clupdata/features/calendar/domain/wochen_utils.dart';

void main() {
  group('montagVon', () {
    test('liefert denselben Tag bei einem Montag', () {
      // 05.10.2026 ist ein Montag
      expect(montagVon(DateTime(2026, 10, 5)), DateTime(2026, 10, 5));
    });

    test('liefert den Montag derselben Woche bei Mittwoch', () {
      // 07.10.2026 ist ein Mittwoch
      expect(montagVon(DateTime(2026, 10, 7)), DateTime(2026, 10, 5));
    });

    test('liefert den Montag derselben Woche bei Sonntag', () {
      // 11.10.2026 ist ein Sonntag (Ende der Woche Mo 05.10.)
      expect(montagVon(DateTime(2026, 10, 11)), DateTime(2026, 10, 5));
    });

    test('entfernt die Uhrzeit', () {
      expect(montagVon(DateTime(2026, 10, 7, 15, 30)), DateTime(2026, 10, 5));
    });
  });

  group('wochenBereich', () {
    test('umfasst Montag bis Sonntag', () {
      final bereich = wochenBereich(DateTime(2026, 10, 7));
      expect(bereich.montag, DateTime(2026, 10, 5));
      expect(bereich.sonntag, DateTime(2026, 10, 11));
    });
  });

  group('formatiereWochenBereich', () {
    test('formatiert deutschen Bereich', () {
      expect(
        formatiereWochenBereich(DateTime(2026, 10, 7)),
        '05.10. – 11.10.2026',
      );
    });
  });

  group('parseZeit', () {
    test('parst gültige Zeiten', () {
      expect(parseZeit('18:30'), 18 * 60 + 30);
      expect(parseZeit('09:05'), 9 * 60 + 5);
      expect(parseZeit('00:00'), 0);
      expect(parseZeit('23:59'), 23 * 60 + 59);
    });

    test('akzeptiert einstellige Stunden', () {
      expect(parseZeit('9:05'), 9 * 60 + 5);
    });

    test('lehnt ungültige Zeiten ab', () {
      expect(parseZeit('24:00'), isNull);
      expect(parseZeit('18:60'), isNull);
      expect(parseZeit('abc'), isNull);
      expect(parseZeit(''), isNull);
      expect(parseZeit('18.30'), isNull);
    });
  });

  group('formatiereZeit', () {
    test('formatiert mit führenden Nullen', () {
      expect(formatiereZeit(18 * 60 + 30), '18:30');
      expect(formatiereZeit(9 * 60 + 5), '09:05');
      expect(formatiereZeit(0), '00:00');
    });
  });
}
