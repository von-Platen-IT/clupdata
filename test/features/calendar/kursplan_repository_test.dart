import 'dart:ffi';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/features/calendar/data/kursplan_repository.dart';

void main() {
  late AppDatabase db;
  late KursplanRepository repo;

  setUpAll(() {
    // Linux-Systeme haben oft nur libsqlite3.so.0 (ohne Dev-Link .so).
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = KursplanRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── Testdaten-Helfer ────────────────────────────────────────────────────

  Future<int> legeKurs({
    String name = 'Boxen Erwachsene',
    String sportart = 'Boxen',
    String farbe = '#FFCDD2',
  }) {
    return repo.createKurs(name: name, kampfsportart: sportart, farbe: farbe);
  }

  Future<int> legeTermin({
    required int kursplanId,
    required int kursId,
    int wochentag = 1,
    String startzeit = '18:00',
    String? endezeit,
  }) {
    return db
        .into(db.kursplanTermine)
        .insert(
          KursplanTermineCompanion.insert(
            kursplanId: kursplanId,
            kursId: kursId,
            wochentag: wochentag,
            startzeit: startzeit,
            endezeit: drift.Value(endezeit),
          ),
        );
  }

  // ── Kurse ───────────────────────────────────────────────────────────────

  group('Kurse', () {
    test('createKurs + watchKurse liefert RowData', () async {
      final id = await legeKurs(farbe: '#A5D6A7');

      final kurse = await repo.watchKurse().first;
      expect(kurse, hasLength(1));
      expect(kurse.single.id, id);
      expect(kurse.single.name, 'Boxen Erwachsene');
      expect(kurse.single.kampfsportart, 'Boxen');
      expect(kurse.single.farbe, '#A5D6A7');
    });

    test('updateKurs ändert die Felder', () async {
      final id = await legeKurs();
      final kurs = (await repo.watchKurse().first).single;

      await repo.updateKurs(
        kurs.copyWith(name: 'Kickboxen', kampfsportart: 'Kickboxen'),
      );

      final aktualisiert = (await repo.watchKurse().first).single;
      expect(aktualisiert.id, id);
      expect(aktualisiert.name, 'Kickboxen');
      expect(aktualisiert.kampfsportart, 'Kickboxen');
    });

    test('deleteKurs ohne Termine funktioniert', () async {
      final id = await legeKurs();
      await repo.deleteKurs(id);
      expect(await repo.watchKurse().first, isEmpty);
    });

    test('deleteKurs mit Terminen wird abgelehnt (RESTRICT)', () async {
      final kursId = await legeKurs();
      final planId = await repo.saveKursplan(
        name: 'Plan',
        gueltigVon: DateTime(2026, 10, 5),
        termine: [
          KursplanTermineCompanion.insert(
            kursplanId: 0,
            kursId: kursId,
            wochentag: 1,
            startzeit: '18:00',
          ),
        ],
      );
      expect(planId, greaterThan(0));

      await expectLater(repo.deleteKurs(kursId), throwsA(isA<Exception>()));
    });
  });

  // ── Kurspläne ───────────────────────────────────────────────────────────

  group('Kurspläne', () {
    test('saveKursplan normalisiert gueltigVon auf den Montag', () async {
      // Mittwoch, 07.01.2026 → Montag, 05.01.2026
      await repo.saveKursplan(
        name: 'Winterplan',
        gueltigVon: DateTime(2026, 1, 7),
        gueltigBis: DateTime(2026, 1, 14),
        termine: [],
      );

      final plan = (await repo.watchKursplaene().first).single;
      expect(plan.gueltigVon, DateTime(2026, 1, 5));
      expect(plan.gueltigBis, DateTime(2026, 1, 12));
    });

    test('saveKursplan Update ändert Name und Gültigkeit', () async {
      await repo.saveKursplan(
        name: 'Alt',
        gueltigVon: DateTime(2026, 1, 5),
        termine: [],
      );
      final plan = (await repo.watchKursplaene().first).single;

      await repo.saveKursplan(
        bestehend: plan,
        name: 'Neu',
        gueltigVon: DateTime(2026, 2, 2),
        gueltigBis: null,
        termine: [],
      );

      final aktualisiert = (await repo.watchKursplaene().first).single;
      expect(aktualisiert.id, plan.id);
      expect(aktualisiert.name, 'Neu');
      expect(aktualisiert.gueltigVon, DateTime(2026, 2, 2));
      expect(aktualisiert.gueltigBis, isNull);
    });

    test('loadGueltigePlaene findet Pläne im Gültigkeitszeitraum', () async {
      await repo.saveKursplan(
        name: 'Q1',
        gueltigVon: DateTime(2026, 1, 5),
        gueltigBis: DateTime(2026, 3, 30),
        termine: [],
      );
      await repo.saveKursplan(
        name: 'Ab April',
        gueltigVon: DateTime(2026, 3, 30),
        gueltigBis: null,
        termine: [],
      );

      // Woche im Februar → nur Q1
      final februar = await repo.loadGueltigePlaene(DateTime(2026, 2, 10));
      expect(februar.map((p) => p.name), ['Q1']);

      // Woche im Mai → nur "Ab April"
      final mai = await repo.loadGueltigePlaene(DateTime(2026, 5, 10));
      expect(mai.map((p) => p.name), ['Ab April']);

      // Woche vor Q1 → leer
      final dezember = await repo.loadGueltigePlaene(DateTime(2025, 12, 10));
      expect(dezember, isEmpty);
    });

    test(
      'bei Überschneidung gewinnt der Plan mit dem spätesten gueltigVon',
      () async {
        await repo.saveKursplan(
          name: 'Alt',
          gueltigVon: DateTime(2026, 1, 5),
          gueltigBis: DateTime(2026, 3, 30),
          termine: [],
        );
        await repo.saveKursplan(
          name: 'Neu',
          gueltigVon: DateTime(2026, 2, 2),
          gueltigBis: DateTime(2026, 3, 30),
          termine: [],
        );

        final plaene = await repo.loadGueltigePlaene(DateTime(2026, 2, 10));
        expect(plaene, hasLength(2));
        expect(plaene.first.name, 'Neu'); // spätester gueltigVon zuerst
      },
    );

    test('deleteKursplan entfernt auch die Termine (CASCADE)', () async {
      final kursId = await legeKurs();
      final planId = await repo.saveKursplan(
        name: 'Plan',
        gueltigVon: DateTime(2026, 10, 5),
        termine: [
          KursplanTermineCompanion.insert(
            kursplanId: 0,
            kursId: kursId,
            wochentag: 1,
            startzeit: '18:00',
          ),
        ],
      );

      expect(await repo.loadTermine(planId), hasLength(1));
      await repo.deleteKursplan(planId);
      expect(await repo.loadTermine(planId), isEmpty);
    });
  });

  // ── Termine ─────────────────────────────────────────────────────────────

  group('Termine', () {
    test('loadTermine liefert Join mit Kursdaten', () async {
      final kursId = await legeKurs(farbe: '#90CAF9');
      final planId = await repo.saveKursplan(
        name: 'Plan',
        gueltigVon: DateTime(2026, 10, 5),
        termine: [
          KursplanTermineCompanion.insert(
            kursplanId: 0,
            kursId: kursId,
            wochentag: 3,
            startzeit: '17:30',
            endezeit: const drift.Value('19:00'),
          ),
        ],
      );

      final termine = await repo.loadTermine(planId);
      expect(termine, hasLength(1));
      expect(termine.single.kursName, 'Boxen Erwachsene');
      expect(termine.single.kampfsportart, 'Boxen');
      expect(termine.single.farbe, '#90CAF9');
      expect(termine.single.wochentag, 3);
      expect(termine.single.startzeit, '17:30');
      expect(termine.single.endezeit, '19:00');
      expect(termine.single.startMinuten, 17 * 60 + 30);
      expect(termine.single.endMinuten, 19 * 60);
    });

    test('CHECK: endezeit muss nach startzeit liegen', () async {
      final kursId = await legeKurs();
      final planId = await repo.saveKursplan(
        name: 'Plan',
        gueltigVon: DateTime(2026, 10, 5),
        termine: [],
      );

      await expectLater(
        legeTermin(
          kursplanId: planId,
          kursId: kursId,
          startzeit: '18:00',
          endezeit: '17:00',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('replaceTermine ersetzt alle Termine eines Plans', () async {
      final kursId = await legeKurs();
      final planId = await repo.saveKursplan(
        name: 'Plan',
        gueltigVon: DateTime(2026, 10, 5),
        termine: [
          KursplanTermineCompanion.insert(
            kursplanId: 0,
            kursId: kursId,
            wochentag: 1,
            startzeit: '18:00',
          ),
        ],
      );

      await repo.replaceTermine(planId, [
        KursplanTermineCompanion.insert(
          kursplanId: 0,
          kursId: kursId,
          wochentag: 2,
          startzeit: '19:00',
        ),
        KursplanTermineCompanion.insert(
          kursplanId: 0,
          kursId: kursId,
          wochentag: 4,
          startzeit: '19:00',
        ),
      ]);

      final termine = await repo.loadTermine(planId);
      expect(termine, hasLength(2));
      expect(termine.map((t) => t.wochentag), [2, 4]);
    });
  });
}
