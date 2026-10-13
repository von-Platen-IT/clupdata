import 'package:flutter_test/flutter_test.dart';

import 'package:clupdata/features/schnellerfassung/domain/models/schnellerfassung_felder.dart';

void main() {
  group('alsNaechsteVorlage (Auto-Vorlage)', () {
    test('behält Komfortfelder, leert Personenfelder', () {
      final felder = SchnellerfassungFelder(
        anrede: 'Frau',
        geschlecht: 'weiblich',
        name: 'Mustermann',
        vorname: 'Maria',
        geboren: DateTime(1990, 1, 1),
        plz: '12345',
        ort: 'Musterstadt',
        strasse: 'Hauptstrasse',
        hausnummer: '1',
        telefon: '030 123',
        email: 'maria@example.com',
        leistungId: 7,
        vertragVon: DateTime(2026, 10, 1),
        bemerkung: 'Notiz',
      );

      final naechste = felder.alsNaechsteVorlage();

      // Personenfelder geleert
      expect(naechste.name, '');
      expect(naechste.vorname, '');
      expect(naechste.geboren, isNull);
      expect(naechste.telefon, '');
      expect(naechste.email, '');
      expect(naechste.bemerkung, '');

      // Komfortfelder behalten
      expect(naechste.anrede, 'Frau');
      expect(naechste.geschlecht, 'weiblich');
      expect(naechste.plz, '12345');
      expect(naechste.ort, 'Musterstadt');
      expect(naechste.strasse, 'Hauptstrasse');
      expect(naechste.hausnummer, '1');
      expect(naechste.leistungId, 7);
      expect(naechste.vertragVon, DateTime(2026, 10, 1));
    });
  });

  group('toMap / fromMap (Vorlagen-Serialisierung)', () {
    test('Roundtrip bleibt identisch', () {
      final felder = SchnellerfassungFelder(
        anrede: 'Herr',
        geschlecht: 'maennlich',
        name: 'Beispiel',
        vorname: 'Hans',
        geboren: DateTime(1985, 5, 20),
        plz: '54321',
        ort: 'Beispielstadt',
        leistungId: 3,
        vertragVon: DateTime(2026, 1, 1),
      );

      final wiederhergestellt = SchnellerfassungFelder.fromMap(felder.toMap());

      expect(wiederhergestellt, felder);
    });

    test('leere Felder werden als leere Strings serialisiert', () {
      const felder = SchnellerfassungFelder();
      final map = felder.toMap();

      expect(map['name'], '');
      expect(map['geboren'], '');
      expect(map['leistungId'], '');

      final wiederhergestellt = SchnellerfassungFelder.fromMap(map);
      expect(wiederhergestellt.leistungId, isNull);
      expect(wiederhergestellt.geboren, isNull);
    });

    test('fromMap toleriert fehlende Schlüssel', () {
      final felder = SchnellerfassungFelder.fromMap({'name': 'Test'});
      expect(felder.name, 'Test');
      expect(felder.vorname, '');
      expect(felder.leistungId, isNull);
    });
  });
}
