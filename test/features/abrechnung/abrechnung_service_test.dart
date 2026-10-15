import 'dart:ffi';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/features/abrechnung/data/abrechnung_service.dart';
import 'package:clupdata/features/abrechnung/domain/models/abrechnungslauf_state.dart';
import 'package:clupdata/features/abrechnung/domain/models/zeitraum_typ.dart';
import 'package:clupdata/features/billing/services/faelligkeit_service.dart';

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
    service = AbrechnungService(db, const FaelligkeitService());
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
  AbrechnungslaufState monatState({
    List<int> mitgliedIds = const [],
    List<int> leistungIds = const [],
    bool nurAktiveVertraege = false,
    bool nurOhneOffene = false,
    String? bemerkung,
    int zahlungszielTage = 14,
  }) {
    return AbrechnungslaufState(
      zeitraumTyp: ZeitraumTyp.monat,
      jahr: 2026,
      monat: 6,
      mitgliedIds: mitgliedIds,
      leistungIds: leistungIds,
      nurAktiveVertraege: nurAktiveVertraege,
      nurOhneOffene: nurOhneOffene,
      bemerkung: bemerkung,
      zahlungszielTage: zahlungszielTage,
    );
  }

  // ── ladeVorschau ────────────────────────────────────────────────────────

  group('ladeVorschau', () {
    test('erzeugt eine Zeile je Mitglied (monatlich)', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      await legeMitglied('Mustermann', leistungId: leistungId);
      await legeMitglied('Beispiel', leistungId: leistungId);

      final zeilen = await service.ladeVorschau(monatState());

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
              faelligAm: DateTime(2026, 6, 15),
              statusDatum: DateTime(2026, 6, 1),
            ),
          );

      final zeilen = await service.ladeVorschau(monatState());

      expect(zeilen, hasLength(2));
      final betroffen = zeilen.where((z) => z.mitgliedId == m1).toList();
      expect(betroffen.single.bereitsAbgerechnet, isTrue);
      expect(betroffen.single.inkludiert, isFalse);
    });

    test('setzt die Fälligkeit aus dem Zahlungsziel', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      await legeMitglied('Mustermann', leistungId: leistungId);

      final zeilen = await service.ladeVorschau(monatState(zahlungszielTage: 30));

      // Fälligkeit = heute + 30 Tage (FaelligkeitService-Ziel)
      final erwartet = DateTime.now().add(const Duration(days: 30));
      expect(zeilen.single.faelligAm.year, erwartet.year);
      expect(zeilen.single.faelligAm.month, erwartet.month);
      expect(zeilen.single.faelligAm.day, erwartet.day);
    });
  });

  // ── fuehreAus ───────────────────────────────────────────────────────────

  group('fuehreAus', () {
    test('erstellt Beiträge mit Status-Verlauf und Fälligkeit', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      await legeMitglied('Mustermann', leistungId: leistungId);
      await legeMitglied('Beispiel', leistungId: leistungId);

      final zeilen = await service.ladeVorschau(monatState());
      final ergebnis = await service.fuehreAus(zeilen, monatState());

      expect(ergebnis.erstelltAnzahl, 2);
      expect(ergebnis.fehler, isEmpty);
      expect(ergebnis.gesamtBetrag, 90);

      final beitraege = await db.select(db.beitraege).get();
      expect(beitraege, hasLength(2));
      expect(beitraege.every((b) => b.faelligAm.isAfter(DateTime.now())), isTrue);

      final verlauf = await db.select(db.beitragStatusVerlauf).get();
      expect(verlauf, hasLength(2), reason: 'Jeder Beitrag braucht einen initialen Verlauf');
      expect(verlauf.every((v) => v.bemerkung.isNotEmpty), isTrue);
    });

    test('ist idempotent – zweiter Lauf erstellt keine Duplikate', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      await legeMitglied('Mustermann', leistungId: leistungId);

      final zeilen = await service.ladeVorschau(monatState());
      await service.fuehreAus(zeilen, monatState());

      final zweiteZeilen = await service.ladeVorschau(monatState());
      final zweitesErgebnis = await service.fuehreAus(zweiteZeilen, monatState());

      expect(zweitesErgebnis.erstelltAnzahl, 0);
      expect(zweitesErgebnis.uebersprungenAnzahl, 1);

      final beitraege = await db.select(db.beitraege).get();
      expect(beitraege, hasLength(1), reason: 'Kein Duplikat für gleiche Periode');
    });

    test('speichert den Preis-Snapshot (kein Live-Bezug)', () async {
      final leistungId = await legeLeistung('Boxen', 45, 'monatlich');
      await legeMitglied('Mustermann', leistungId: leistungId);

      final zeilen = await service.ladeVorschau(monatState());
      await service.fuehreAus(zeilen, monatState());

      // Leistungspreis erhöhen – der Snapshot muss erhalten bleiben.
      final leistung = await db.select(db.leistung).getSingle();
      await (db.update(db.preis)..where((p) => p.id.equals(leistung.preisId)))
          .write(const PreisCompanion(bruttopreis: drift.Value(99.0)));

      final beitrag = await db.select(db.beitraege).getSingle();
      final preis = await (db.select(db.preis)
            ..where((p) => p.id.equals(beitrag.preisId!)))
          .getSingle();
      expect(preis.bruttopreis, 45);
    });
  });
}
