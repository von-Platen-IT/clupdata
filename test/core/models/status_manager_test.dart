import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clupdata/core/models/status_manager.dart';
import 'package:clupdata/features/beitraege/domain/models/beitrag_status.dart';
import 'package:clupdata/features/rechnungen/domain/models/rechnung_status.dart';

void main() {
  group('StatusManager interface', () {
    test('BeitragStatus implements StatusManager', () {
      // All BeitragStatus values should be assignable to StatusManager
      for (final status in BeitragStatus.values) {
        final StatusManager mgr = status;
        expect(mgr.value, isNotEmpty);
        expect(mgr.label, isNotEmpty);
        expect(mgr.backgroundColor, isA<Color>());
        expect(mgr.textColor, isA<Color>());
      }
    });

    test('RechnungStatus implements StatusManager', () {
      for (final status in RechnungStatus.values) {
        final StatusManager mgr = status;
        expect(mgr.value, isNotEmpty);
        expect(mgr.label, isNotEmpty);
        expect(mgr.backgroundColor, isA<Color>());
        expect(mgr.textColor, isA<Color>());
      }
    });

    test('StatusManager.fromString resolves correctly', () {
      final result = StatusManager.fromString('offen', RechnungStatus.values);
      expect(result, RechnungStatus.offen);
    });

    test('StatusManager.fromString is case-insensitive', () {
      final result = StatusManager.fromString('BEZAHLT', RechnungStatus.values);
      expect(result, RechnungStatus.bezahlt);
    });

    test('StatusManager.fromString falls back to first value on unknown', () {
      final result = StatusManager.fromString(
        'nonexistent',
        RechnungStatus.values,
      );
      expect(result, RechnungStatus.values.first);
    });

    test('StatusManager.allStringValues returns string list', () {
      final strings = StatusManager.allStringValues(RechnungStatus.values);
      expect(strings, ['offen', 'bezahlt', 'storniert']);
    });
  });

  group('BeitragStatus', () {
    test('has 6 values', () {
      expect(BeitragStatus.values.length, 6);
    });

    test('labels are in German', () {
      expect(BeitragStatus.kontiert.label, 'Kontiert');
      expect(BeitragStatus.offen.label, 'Offen');
      expect(BeitragStatus.bezahlt.label, 'Bezahlt');
      expect(BeitragStatus.angemahnt.label, 'Angemahnt');
      expect(BeitragStatus.storniert.label, 'Storniert');
      expect(BeitragStatus.inkasso.label, 'Inkasso');
    });

    test('fromString resolves case-insensitively', () {
      expect(BeitragStatus.fromString('offen'), BeitragStatus.offen);
      expect(BeitragStatus.fromString('OFFEN'), BeitragStatus.offen);
      expect(BeitragStatus.fromString('Angemahnt'), BeitragStatus.angemahnt);
    });

    test('fromString falls back to kontiert on unknown', () {
      expect(BeitragStatus.fromString('invalid'), BeitragStatus.kontiert);
    });

    test('value getter returns name', () {
      expect(BeitragStatus.offen.value, 'offen');
      expect(BeitragStatus.bezahlt.value, 'bezahlt');
    });

    test('backgroundColor returns non-transparent color', () {
      // All known statuses should have a non-transparent background
      for (final status in BeitragStatus.values) {
        expect(status.backgroundColor, isNot(Colors.transparent));
      }
    });

    test('status predicates work correctly', () {
      expect(BeitragStatus.kontiert.isEditable, isTrue);
      expect(BeitragStatus.offen.isEditable, isTrue);
      expect(BeitragStatus.bezahlt.isEditable, isFalse);
      expect(BeitragStatus.storniert.isEditable, isFalse);

      expect(BeitragStatus.offen.isOpen, isTrue);
      expect(BeitragStatus.angemahnt.isOpen, isTrue);
      expect(BeitragStatus.bezahlt.isOpen, isFalse);

      expect(BeitragStatus.bezahlt.isFinal, isTrue);
      expect(BeitragStatus.storniert.isFinal, isTrue);
      expect(BeitragStatus.offen.isFinal, isFalse);
    });

    test('allStringValues returns 6 strings', () {
      expect(BeitragStatus.allStringValues.length, 6);
      expect(BeitragStatus.allStringValues, contains('offen'));
    });
  });

  group('RechnungStatus', () {
    test('has 3 values', () {
      expect(RechnungStatus.values.length, 3);
    });

    test('labels are in German', () {
      expect(RechnungStatus.offen.label, 'Offen');
      expect(RechnungStatus.bezahlt.label, 'Bezahlt');
      expect(RechnungStatus.storniert.label, 'Storniert');
    });

    test('fromString resolves case-insensitively', () {
      expect(RechnungStatus.fromString('offen'), RechnungStatus.offen);
      expect(RechnungStatus.fromString('BEZAHLT'), RechnungStatus.bezahlt);
      expect(RechnungStatus.fromString('Storniert'), RechnungStatus.storniert);
    });

    test('fromString falls back to first value on unknown', () {
      expect(RechnungStatus.fromString('invalid'), RechnungStatus.values.first);
    });

    test('value getter returns name', () {
      expect(RechnungStatus.offen.value, 'offen');
      expect(RechnungStatus.bezahlt.value, 'bezahlt');
    });

    test('backgroundColor returns non-transparent color', () {
      for (final status in RechnungStatus.values) {
        expect(status.backgroundColor, isNot(Colors.transparent));
      }
    });

    test('allStringValues returns 3 strings', () {
      expect(RechnungStatus.allStringValues.length, 3);
      expect(RechnungStatus.allStringValues, contains('bezahlt'));
    });
  });

  group('Shared status colors', () {
    test('Beitrag and Rechnung share color for "offen"', () {
      expect(
        BeitragStatus.offen.backgroundColor,
        RechnungStatus.offen.backgroundColor,
      );
    });

    test('Beitrag and Rechnung share color for "bezahlt"', () {
      expect(
        BeitragStatus.bezahlt.backgroundColor,
        RechnungStatus.bezahlt.backgroundColor,
      );
    });

    test('Beitrag and Rechnung share color for "storniert"', () {
      expect(
        BeitragStatus.storniert.backgroundColor,
        RechnungStatus.storniert.backgroundColor,
      );
    });
  });
}
