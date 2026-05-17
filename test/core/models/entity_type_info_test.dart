import 'package:flutter_test/flutter_test.dart';

import 'package:clupdata/core/models/entity_type_info.dart';

void main() {
  group('EntityTypeInfo', () {
    group('detect', () {
      test('detects rechnung from German text', () {
        expect(EntityTypeInfo.detect('Rechnung bearbeiten'), 'rechnung');
      });

      test('detects mitglied from German text', () {
        expect(EntityTypeInfo.detect('Mitglied Max Mustermann'), 'mitglied');
      });

      test('detects beitrag from German text', () {
        expect(EntityTypeInfo.detect('Beitrag 2026-01'), 'beitrag');
      });

      test('detects leistung from German text', () {
        expect(EntityTypeInfo.detect('Leistung Monatlich'), 'leistung');
      });

      test('detects ware from German text', () {
        expect(EntityTypeInfo.detect('Waren exportieren'), 'ware');
      });

      test('is case-insensitive', () {
        expect(EntityTypeInfo.detect('RECHNUNG'), 'rechnung');
        expect(EntityTypeInfo.detect('Mitglied'), 'mitglied');
      });

      test('returns null for unknown entity', () {
        expect(EntityTypeInfo.detect('Unbekannte Entität'), isNull);
      });

      test('returns null for null input', () {
        expect(EntityTypeInfo.detect(null), isNull);
      });
    });

    group('displayNameFor', () {
      test('returns German display name for known types', () {
        expect(EntityTypeInfo.displayNameFor('mitglied'), 'Mitglieder');
        expect(EntityTypeInfo.displayNameFor('rechnung'), 'Rechnungen');
        expect(EntityTypeInfo.displayNameFor('beitrag'), 'Beiträge');
        expect(EntityTypeInfo.displayNameFor('leistung'), 'Leistungen');
        expect(EntityTypeInfo.displayNameFor('ware'), 'Waren');
      });

      test('is case-insensitive', () {
        expect(EntityTypeInfo.displayNameFor('MITGLIED'), 'Mitglieder');
        expect(EntityTypeInfo.displayNameFor('Rechnung'), 'Rechnungen');
      });

      test('returns input unchanged for unknown types', () {
        expect(EntityTypeInfo.displayNameFor('unbekannt'), 'unbekannt');
      });
    });

    group('enum values', () {
      test('has 5 values', () {
        expect(EntityTypeInfo.values.length, 5);
      });

      test('each has a displayName', () {
        for (final type in EntityTypeInfo.values) {
          expect(type.displayName, isNotEmpty);
        }
      });
    });
  });
}
