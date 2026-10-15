import 'dart:ffi';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

import 'package:clupdata/core/data/rechnungsnummer_generator.dart';
import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/features/billing/data/mahnung_repository.dart';
import 'package:clupdata/features/billing/data/offene_posten_repository.dart';
import 'package:clupdata/features/billing/domain/models/zahlungsart.dart';
import 'package:clupdata/features/billing/services/faelligkeit_service.dart';
import 'package:clupdata/features/billing/services/mahnung_service.dart';
import 'package:clupdata/features/billing/services/zahlung_service.dart';

void main() {
  late AppDatabase db;
  late int mitgliedId;
  late int leistungId;

  setUpAll(() {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final preisId = await db.into(db.preis).insert(PreisCompanion.insert(bruttopreis: 10));
    leistungId = await db.into(db.leistung).insert(
          LeistungCompanion.insert(name: 'Boxen', preisId: preisId, laufzeit: 'monatlich'),
        );
    mitgliedId = await db.into(db.mitglieds).insert(
          MitgliedsCompanion.insert(name: 'Muster', vorname: 'Max'),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> legeBeitrag({
    required double betrag,
    required DateTime faelligAm,
    String status = 'offen',
    String nummer = 'RE-2026-00001',
  }) async {
    final preisId = await db.into(db.preis).insert(PreisCompanion.insert(bruttopreis: betrag));
    final jetzt = DateTime.now();
    return db.into(db.beitraege).insert(
          BeitraegeCompanion.insert(
            mitgliedId: mitgliedId,
            leistungId: leistungId,
            preisId: drift.Value(preisId),
            rechnungsnummer: nummer,
            status: status,
            kontiertAm: jetzt,
            faelligAm: faelligAm,
            statusDatum: jetzt,
          ),
        );
  }

  DateTime vorTagen(int tage) {
    final h = DateTime.now();
    return DateTime(h.year, h.month, h.day - tage);
  }

  group('FaelligkeitService.istUeberfaellig', () {
    const service = FaelligkeitService();

    test('am Fälligkeitstag noch nicht überfällig', () {
      expect(
        service.istUeberfaellig(DateTime(2026, 6, 10), heute: DateTime(2026, 6, 10, 15)),
        isFalse,
      );
    });

    test('am Folgetag überfällig', () {
      expect(
        service.istUeberfaellig(DateTime(2026, 6, 10), heute: DateTime(2026, 6, 11, 0, 1)),
        isTrue,
      );
    });

    test('Toleranz wird berücksichtigt', () {
      const mitToleranz = FaelligkeitService(toleranzTage: 3);
      expect(
        mitToleranz.istUeberfaellig(DateTime(2026, 6, 10), heute: DateTime(2026, 6, 13)),
        isFalse,
      );
      expect(
        mitToleranz.istUeberfaellig(DateTime(2026, 6, 10), heute: DateTime(2026, 6, 14)),
        isTrue,
      );
    });
  });

  group('OffenePostenRepository', () {
    test('liefert offene Beiträge und berücksichtigt Teilzahlungen', () async {
      final id = await legeBeitrag(betrag: 50, faelligAm: vorTagen(10));
      await ZahlungService(db).bucheZahlungFuerBeitrag(
        beitragId: id,
        betrag: 20,
        zahlungsart: Zahlungsart.values.first,
      );

      final posten = await OffenePostenRepository(db).ladeOffenePosten();

      expect(posten, hasLength(1));
      expect(posten.first.betrag, 50);
      expect(posten.first.saldo, 30);
      expect(posten.first.tageUeberfaellig, 10);
    });

    test('vollständig bezahlte Beiträge erscheinen nicht', () async {
      await legeBeitrag(betrag: 50, faelligAm: vorTagen(1), status: 'bezahlt');
      expect(await OffenePostenRepository(db).ladeOffenePosten(), isEmpty);
    });

    test('nurUeberfaellig filtert nicht fällige Posten', () async {
      await legeBeitrag(betrag: 50, faelligAm: vorTagen(-5));
      final repo = OffenePostenRepository(db);
      expect(await repo.ladeOffenePosten(), hasLength(1));
      expect(await repo.ladeOffenePosten(nurUeberfaellig: true), isEmpty);
    });
  });

  group('ZahlungService Validierung', () {
    test('Betrag <= 0 wird abgelehnt', () async {
      final id = await legeBeitrag(betrag: 50, faelligAm: vorTagen(1));
      expect(
        () => ZahlungService(db).bucheZahlungFuerBeitrag(
          beitragId: id,
          betrag: 0,
          zahlungsart: Zahlungsart.values.first,
        ),
        throwsArgumentError,
      );
    });

    test('stornierter Beleg wird abgelehnt', () async {
      final id = await legeBeitrag(betrag: 50, faelligAm: vorTagen(1), status: 'storniert');
      expect(
        () => ZahlungService(db).bucheZahlungFuerBeitrag(
          beitragId: id,
          betrag: 10,
          zahlungsart: Zahlungsart.values.first,
        ),
        throwsStateError,
      );
    });
  });

  group('MahnungService', () {
    MahnungService baueService() => MahnungService(
          db,
          OffenePostenRepository(db),
          MahnungRepository(db),
          const Mahnkonfiguration(),
        );

    test('Stufe 1 erst nach Frist', () async {
      await legeBeitrag(betrag: 50, faelligAm: vorTagen(3));
      expect(await baueService().berechneMahnvorschlaege(), isEmpty);
    });

    test('Stufe 4 wird nicht direkt nach Stufe 3 vorgeschlagen', () async {
      final id = await legeBeitrag(betrag: 50, faelligAm: vorTagen(22));
      for (final stufe in [1, 2, 3]) {
        await MahnungRepository(db).insertMahnung(
          MahnungenCompanion.insert(
            beitragId: drift.Value(id),
            stufe: stufe,
            datum: DateTime.now(),
            forderung: 50,
          ),
        );
      }
      expect(await baueService().berechneMahnvorschlaege(), isEmpty);
    });

    test('Mahnlauf setzt Status und Historie; Stufe 4 → inkasso', () async {
      final id = await legeBeitrag(betrag: 50, faelligAm: vorTagen(31));
      final service = baueService();
      final vorschlaege = await service.berechneMahnvorschlaege();
      expect(vorschlaege.single.stufe, 1);

      final ergebnis = await service.erstelleMahnlauf(vorschlaege);
      expect(ergebnis.fehler, isEmpty);

      final beitrag = await (db.select(db.beitraege)..where((b) => b.id.equals(id))).getSingle();
      expect(beitrag.status, 'angemahnt');
      final verlauf = await db.select(db.beitragStatusVerlauf).get();
      expect(verlauf, hasLength(1));
    });
  });

  group('RechnungsnummerGenerator', () {
    test('Beitragsnummern zählen fortlaufend', () async {
      await legeBeitrag(betrag: 10, faelligAm: vorTagen(1), nummer: 'RE-${DateTime.now().year}-00007');
      final nummer = await RechnungsnummerGenerator(db).generateForBeitrag();
      expect(nummer, 'RE-${DateTime.now().year}-00008');
    });
  });
}
