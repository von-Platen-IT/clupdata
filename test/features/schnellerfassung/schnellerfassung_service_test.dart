import 'dart:ffi';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

import 'package:clupdata/core/data/bemerkung_repository.dart';
import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/features/members/data/members_repository.dart';
import 'package:clupdata/features/schnellerfassung/domain/models/schnellerfassung_felder.dart';
import 'package:clupdata/features/schnellerfassung/services/schnellerfassung_service.dart';

void main() {
  late AppDatabase db;
  late SchnellerfassungService service;

  setUpAll(() {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = SchnellerfassungService(
      db,
      MembersRepository(db, BemerkungRepository(db)),
      BemerkungRepository(db),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> legeLeistung(String name, String laufzeit) async {
    final preisId = await db
        .into(db.preis)
        .insert(PreisCompanion.insert(bruttopreis: 45));
    return db
        .into(db.leistung)
        .insert(
          LeistungCompanion.insert(
            name: name,
            preisId: preisId,
            laufzeit: laufzeit,
          ),
        );
  }

  group('speichereMitglied', () {
    test('legt ein Mitglied mit allen Feldern an', () async {
      final leistungId = await legeLeistung('Boxen', 'monatlich');
      final id = await service.speichereMitglied(
        SchnellerfassungFelder(
          anrede: 'Frau',
          geschlecht: 'weiblich',
          name: 'Mustermann',
          vorname: 'Maria',
          geboren: DateTime(1990, 1, 1),
          plz: '12345',
          ort: 'Musterstadt',
          telefon: '030 123',
          email: 'maria@example.com',
          leistungId: leistungId,
          vertragVon: DateTime(2026, 10, 1),
        ),
      );

      final mitglied = await (db.select(
        db.mitglieds,
      )..where((m) => m.id.equals(id))).getSingle();
      expect(mitglied.name, 'Mustermann');
      expect(mitglied.vorname, 'Maria');
      expect(mitglied.anrede, 'Frau');
      expect(mitglied.plz, '12345');
      expect(mitglied.leistungId, leistungId);
      expect(mitglied.vertragLaufzeitVon, DateTime(2026, 10, 1));
    });

    test('berechnet laufzeitBis aus dem Rhythmus der Leistung', () async {
      final monatlich = await legeLeistung('Monatlich', 'monatlich');
      final quartal = await legeLeistung('Quartal', 'quartalsweise');
      final jaehrlich = await legeLeistung('Jahr', 'jaehrlich');
      final einmalig = await legeLeistung('Einmalig', 'einmalig');

      Future<DateTime?> laufzeitBis(int leistungId) async {
        final id = await service.speichereMitglied(
          SchnellerfassungFelder(
            name: 'Test',
            vorname: 'Test',
            leistungId: leistungId,
            vertragVon: DateTime(2026, 10, 1),
          ),
        );
        final m = await (db.select(
          db.mitglieds,
        )..where((m) => m.id.equals(id))).getSingle();
        return m.vertragLaufzeitBis;
      }

      expect(await laufzeitBis(monatlich), DateTime(2026, 11, 1));
      expect(await laufzeitBis(quartal), DateTime(2027, 1, 1));
      expect(await laufzeitBis(jaehrlich), DateTime(2027, 10, 1));
      expect(await laufzeitBis(einmalig), DateTime(2026, 10, 1));
    });

    test('speichert die Bemerkung und verknüpft sie', () async {
      final id = await service.speichereMitglied(
        const SchnellerfassungFelder(
          name: 'Test',
          vorname: 'Test',
          bemerkung: 'Wichtige Notiz',
        ),
      );

      final mitglied = await (db.select(
        db.mitglieds,
      )..where((m) => m.id.equals(id))).getSingle();
      expect(mitglied.bemerkungId, isNotNull);

      final bemerkung = await (db.select(
        db.bemerkung,
      )..where((b) => b.id.equals(mitglied.bemerkungId!))).getSingle();
      expect(bemerkung.textValue, 'Wichtige Notiz');
    });

    test('ohne Bemerkung bleibt bemerkungId NULL', () async {
      final id = await service.speichereMitglied(
        const SchnellerfassungFelder(name: 'Test', vorname: 'Test'),
      );

      final mitglied = await (db.select(
        db.mitglieds,
      )..where((m) => m.id.equals(id))).getSingle();
      expect(mitglied.bemerkungId, isNull);
    });
  });

  group('istMoeglichesDuplikat', () {
    test('erkennt Namensgleichheit in der Sitzung', () async {
      final duplikat = await service.istMoeglichesDuplikat(
        name: 'Mustermann',
        vorname: 'Maria',
        sitzungsnamen: ['mustermann, maria'],
      );
      expect(duplikat, isTrue);
    });

    test('erkennt Namensgleichheit in der Datenbank', () async {
      await service.speichereMitglied(
        const SchnellerfassungFelder(name: 'Beispiel', vorname: 'Hans'),
      );

      final duplikat = await service.istMoeglichesDuplikat(
        name: 'Beispiel',
        vorname: 'Hans',
        sitzungsnamen: const [],
      );
      expect(duplikat, isTrue);
    });

    test('verschiedene Namen sind kein Duplikat', () async {
      await service.speichereMitglied(
        const SchnellerfassungFelder(name: 'Beispiel', vorname: 'Hans'),
      );

      final duplikat = await service.istMoeglichesDuplikat(
        name: 'Anders',
        vorname: 'Erika',
        sitzungsnamen: const ['Beispiel, Hans'],
      );
      expect(duplikat, isFalse);
    });

    test('leerer Name ist kein Duplikat', () async {
      final duplikat = await service.istMoeglichesDuplikat(
        name: '',
        vorname: '',
        sitzungsnamen: const [],
      );
      expect(duplikat, isFalse);
    });
  });
}
