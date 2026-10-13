import 'dart:ffi';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/features/rechnungserstellung/domain/models/zeitraum_typ.dart';
import 'package:clupdata/features/rechnungserstellung/domain/models/wizard_state.dart';
import 'package:clupdata/features/rechnungserstellung/services/abrechnung_service.dart';

void main() {
  late AppDatabase db;
  late AbrechnungService service;

  setUpAll(() {
    // Linux-Systeme haben oft nur libsqlite3.so.0 (ohne Dev-Link .so).
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = AbrechnungService(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── Testdaten-Helfer ────────────────────────────────────────────────────

  Future<int> legeLeistung(String name, double preis, String laufzeit) async {
    final preisId = await db
        .into(db.preis)
        .insert(PreisCompanion.insert(bruttopreis: preis));
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

  Future<int> legeMitglied(
    String name, {
    int? leistungId,
    int? preisId,
    DateTime? laufzeitBis,
  }) async {
    return db
        .into(db.mitglieds)
        .insert(
          MitgliedsCompanion.insert(
            name: name,
            vorname: 'Test',
            leistungId: drift.Value(leistungId),
            preisId: drift.Value(preisId),
            vertragLaufzeitBis: drift.Value(laufzeitBis),
          ),
        );
  }

  /// Basis-State: Monat Juni 2026, kein Aktiv-Filter (Tests ohne Vertragsdaten).
  WizardState monatState({
    List<int> mitgliedIds = const [],
    List<int> leistungIds = const [],
    bool nurAktiveVertraege = false,
    bool nurOhneOffene = false,
    String? bemerkung,
  }) {
    return WizardState(
      zeitraumTyp: ZeitraumTyp.monat,
      jahr: 2026,
      monat: 6,
      mitgliedIds: mitgliedIds,
      leistungIds: leistungIds,
      nurAktiveVertraege: nurAktiveVertraege,
      nurOhneOffene: nurOhneOffene,
      bemerkung: bemerkung,
    );
  }

  // ── loadVorschau ────────────────────────────────────────────────────────

  group('loadVorschau', () {
    test('erzeugt eine Zeile je Mitglied (Zeitperioden, monatlich)', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      await legeMitglied('Mustermann', leistungId: leistungId);
      await legeMitglied('Beispiel', leistungId: leistungId);

      final zeilen = await service.loadVorschau(monatState());

      expect(zeilen, hasLength(2));
      expect(zeilen.every((z) => z.inkludiert), isTrue);
      expect(zeilen.every((z) => !z.bereitsAbgerechnet), isTrue);
      expect(zeilen.first.betrag, 45);
      expect(zeilen.first.abrechnungsZeitraum, DateTime(2026, 6, 1));
    });

    test('markiert bereits abgerechnete Perioden', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      final m1 = await legeMitglied('Mustermann', leistungId: leistungId);
      await legeMitglied('Beispiel', leistungId: leistungId);

      await db
          .into(db.beitraege)
          .insert(
            BeitraegeCompanion.insert(
              mitgliedId: m1,
              leistungId: leistungId,
              rechnungsnummer: 'RE-2026-00001',
              status: 'kontiert',
              kontiertAm: DateTime(2026, 6, 1),
              abrechnungsZeitraum: drift.Value(DateTime(2026, 6, 1)),
              statusDatum: DateTime(2026, 6, 1),
            ),
          );

      final zeilen = await service.loadVorschau(monatState());

      expect(zeilen, hasLength(2));
      final abgerechnet = zeilen.firstWhere((z) => z.mitgliedId == m1);
      expect(abgerechnet.bereitsAbgerechnet, isTrue);
      expect(abgerechnet.inkludiert, isFalse);
      expect(abgerechnet.hinweis, 'bereits abgerechnet');
    });

    test('quartalsweise erzeugt 4 Perioden im Jahr', () async {
      final leistungId = await legeLeistung('Kurs', 120, 'quartalsweise');
      await legeMitglied('Mustermann', leistungId: leistungId);

      final state = WizardState(
        zeitraumTyp: ZeitraumTyp.jahr,
        jahr: 2026,
        nurAktiveVertraege: false,
      );
      final zeilen = await service.loadVorschau(state);

      expect(zeilen, hasLength(4));
      expect(zeilen.map((z) => z.abrechnungsZeitraum), [
        DateTime(2026, 1, 1),
        DateTime(2026, 4, 1),
        DateTime(2026, 7, 1),
        DateTime(2026, 10, 1),
      ]);
    });

    test('jaehrlich erzeugt 1 Periode im Jahr', () async {
      final leistungId = await legeLeistung('Jahresbeitrag', 500, 'jaehrlich');
      await legeMitglied('Mustermann', leistungId: leistungId);

      final state = WizardState(
        zeitraumTyp: ZeitraumTyp.jahr,
        jahr: 2026,
        nurAktiveVertraege: false,
      );
      final zeilen = await service.loadVorschau(state);

      expect(zeilen, hasLength(1));
      expect(zeilen.first.abrechnungsZeitraum, DateTime(2026, 1, 1));
    });

    test('einmalig wird nach der Abrechnung als erledigt markiert', () async {
      final leistungId = await legeLeistung('Aufnahmegebühr', 25, 'einmalig');
      await legeMitglied('Mustermann', leistungId: leistungId);

      final state = monatState();
      final erste = await service.loadVorschau(state);
      expect(erste.single.bereitsAbgerechnet, isFalse);

      await service.execute(erste, state);

      final zweite = await service.loadVorschau(state);
      expect(zweite.single.bereitsAbgerechnet, isTrue);
    });

    test('Mitgliedspreis hat Vorrang vor Leistungspreis', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      final sonderPreisId = await db
          .into(db.preis)
          .insert(PreisCompanion.insert(bruttopreis: 30));
      await legeMitglied(
        'Mustermann',
        leistungId: leistungId,
        preisId: sonderPreisId,
      );

      final zeilen = await service.loadVorschau(monatState());

      expect(zeilen.single.betrag, 30);
      expect(zeilen.single.hinweis, 'abweichender Einzelpreis');
    });

    test('Modus Einzelmitglied filtert auf mitgliedIds', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      await legeMitglied('Mustermann', leistungId: leistungId);
      final m2 = await legeMitglied('Beispiel', leistungId: leistungId);

      final zeilen = await service.loadVorschau(monatState(mitgliedIds: [m2]));

      expect(zeilen, hasLength(1));
      expect(zeilen.single.mitgliedId, m2);
    });

    test('Modus Kurse filtert auf leistungIds', () async {
      final boxen = await legeLeistung('Boxen', 45, 'monatlich');
      final fitness = await legeLeistung('Fitness', 25, 'monatlich');
      await legeMitglied('Mustermann', leistungId: boxen);
      await legeMitglied('Beispiel', leistungId: fitness);

      final zeilen = await service.loadVorschau(
        monatState(leistungIds: [fitness]),
      );

      expect(zeilen, hasLength(1));
      expect(zeilen.single.leistungName, 'Fitness');
    });

    test('nurAktiveVertraege filtert abgelaufene Verträge', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      await legeMitglied(
        'Aktiv',
        leistungId: leistungId,
        laufzeitBis: DateTime(2027, 1, 1),
      );
      await legeMitglied(
        'Abgelaufen',
        leistungId: leistungId,
        laufzeitBis: DateTime(2020, 1, 1),
      );

      final zeilen = await service.loadVorschau(
        monatState(nurAktiveVertraege: true),
      );

      expect(zeilen, hasLength(1));
      expect(zeilen.single.mitgliedName, startsWith('Aktiv'));
    });

    test('nurOhneOffene filtert Mitglieder mit offenen Beiträgen', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      final m1 = await legeMitglied('Offen', leistungId: leistungId);
      await legeMitglied('Frei', leistungId: leistungId);

      await db
          .into(db.beitraege)
          .insert(
            BeitraegeCompanion.insert(
              mitgliedId: m1,
              leistungId: leistungId,
              rechnungsnummer: 'RE-2026-00001',
              status: 'offen',
              kontiertAm: DateTime(2026, 1, 1),
              statusDatum: DateTime(2026, 1, 1),
            ),
          );

      final zeilen = await service.loadVorschau(
        monatState(nurOhneOffene: true),
      );

      expect(zeilen, hasLength(1));
      expect(zeilen.single.mitgliedName, startsWith('Frei'));
    });
  });

  // ── execute ─────────────────────────────────────────────────────────────

  group('execute', () {
    test('erstellt Beitraege mit Status-Verlauf und Rechnungsnummer', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      await legeMitglied('Mustermann', leistungId: leistungId);
      await legeMitglied('Beispiel', leistungId: leistungId);

      final state = monatState(bemerkung: 'Rechnungslegung Juni');
      final zeilen = await service.loadVorschau(state);
      final result = await service.execute(zeilen, state);

      expect(result.successCount, 2);
      expect(result.skippedCount, 0);
      expect(result.errors, isEmpty);

      final beitraege = await db.select(db.beitraege).get();
      expect(beitraege, hasLength(2));
      for (final b in beitraege) {
        expect(b.rechnungsnummer, matches(RegExp(r'RE-\d{4}-\d{5}')));
        expect(b.status, 'kontiert');
        expect(b.abrechnungsZeitraum, DateTime(2026, 6, 1));
        // Preis-Snapshot angelegt
        expect(b.preisId, isNotNull);
      }

      final verlauf = await db.select(db.beitragStatusVerlauf).get();
      expect(verlauf, hasLength(2));
      expect(
        verlauf.every((v) => v.bemerkung == 'Rechnungslegung Juni'),
        isTrue,
      );
    });

    test('ist idempotent – zweiter Lauf erstellt keine Duplikate', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      await legeMitglied('Mustermann', leistungId: leistungId);
      await legeMitglied('Beispiel', leistungId: leistungId);

      final state = monatState();
      final zeilen = await service.loadVorschau(state);
      await service.execute(zeilen, state);

      // Zweiter Lauf mit denselben (veralteten) Zeilen – execute prüft frisch.
      final zweiterLauf = await service.execute(zeilen, state);
      expect(zweiterLauf.successCount, 0);
      expect(zweiterLauf.skippedCount, 2);

      final beitraege = await db.select(db.beitraege).get();
      expect(beitraege, hasLength(2));
    });

    test('überspringt Zeilen ohne inkludiert-Flag', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      await legeMitglied('Mustermann', leistungId: leistungId);

      final state = monatState();
      final zeilen = await service.loadVorschau(state);
      final ohne = [zeilen.single.copyWith(inkludiert: false)];

      final result = await service.execute(ohne, state);
      expect(result.successCount, 0);
      expect(result.skippedCount, 1);

      final beitraege = await db.select(db.beitraege).get();
      expect(beitraege, isEmpty);
    });

    test('übernimmt überschriebenen Betrag als Preis-Snapshot', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      await legeMitglied('Mustermann', leistungId: leistungId);

      final state = monatState();
      final zeilen = await service.loadVorschau(state);
      final geaendert = [zeilen.single.copyWith(betrag: 33.5)];

      await service.execute(geaendert, state);

      final beitraege = await db.select(db.beitraege).get();
      final preis = await (db.select(
        db.preis,
      )..where((p) => p.id.equals(beitraege.single.preisId!))).getSingle();
      expect(preis.bruttopreis, 33.5);
    });

    test('Standard-Bemerkung wird gesetzt, wenn keine angegeben', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      await legeMitglied('Mustermann', leistungId: leistungId);

      final state = monatState();
      final zeilen = await service.loadVorschau(state);
      await service.execute(zeilen, state);

      final verlauf = await db.select(db.beitragStatusVerlauf).get();
      expect(
        verlauf.single.bemerkung,
        'Beitrag durch Rechnungslegung erstellt',
      );
    });
  });
}
