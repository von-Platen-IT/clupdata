import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/features/backup/data/backup_config_repository.dart';
import 'package:clupdata/features/backup/domain/models/backup_config.dart';
import 'package:clupdata/features/backup/services/backup_scheduler_service.dart';

void main() {
  late AppDatabase db;
  late BackupConfigRepository configRepo;
  late BackupSchedulerService service;

  setUpAll(() {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    configRepo = BackupConfigRepository(db);
    service = BackupSchedulerService(db, configRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('BackupConfig.istFaellig (Intervall-Logik)', () {
    BackupConfig config({
      int intervall = 7,
      bool autoAktiv = true,
      DateTime? letztesDatum,
    }) {
      return BackupConfig(
        pfad: '/tmp/backups',
        intervallTage: intervall,
        autoAktiv: autoAktiv,
        letztesDatum: letztesDatum,
      );
    }

    test('ohne letztes Datum sofort fällig', () {
      expect(config().istFaellig(DateTime(2026, 10, 12)), isTrue);
    });

    test('deaktiviert ist nie fällig', () {
      expect(
        config(
          autoAktiv: false,
          letztesDatum: DateTime(2026, 1, 1),
        ).istFaellig(DateTime(2026, 10, 12)),
        isFalse,
      );
    });

    test('innerhalb des Intervalls nicht fällig', () {
      expect(
        config(
          intervall: 7,
          letztesDatum: DateTime(2026, 10, 10),
        ).istFaellig(DateTime(2026, 10, 12)),
        isFalse,
      );
    });

    test('nach Ablauf des Intervalls fällig', () {
      expect(
        config(
          intervall: 7,
          letztesDatum: DateTime(2026, 10, 5),
        ).istFaellig(DateTime(2026, 10, 12)),
        isTrue,
      );
    });

    test('genau am Intervalltag fällig (alle N Tage)', () {
      expect(
        config(
          intervall: 7,
          letztesDatum: DateTime(2026, 10, 5),
        ).istFaellig(DateTime(2026, 10, 12)),
        isTrue,
      );
    });

    test('naechstesFaellig = letztes Datum + Intervall', () {
      final c = config(intervall: 3, letztesDatum: DateTime(2026, 10, 5));
      expect(c.naechstesFaellig, DateTime(2026, 10, 8));
    });
  });

  group('pruefeUndStarteAutoBackup', () {
    test('führt KEIN Backup aus ohne konfiguriertes Verzeichnis', () async {
      await configRepo.setAutoAktiv(true);
      await configRepo.setIntervall(1);

      final ausgefuehrt = await service.pruefeUndStarteAutoBackup();

      expect(ausgefuehrt, isFalse);
      // Zeitstempel bleibt unverändert (kein Backup).
      expect((await configRepo.loadConfig()).letztesDatum, isNull);
    });

    test('führt KEIN Backup aus wenn deaktiviert', () async {
      await configRepo.setAutoAktiv(false);
      await configRepo.setPfad(Directory.systemTemp.path);

      final ausgefuehrt = await service.pruefeUndStarteAutoBackup();

      expect(ausgefuehrt, isFalse);
    });

    test('führt KEIN Backup aus wenn Intervall noch nicht erreicht', () async {
      await configRepo.setAutoAktiv(true);
      await configRepo.setIntervall(30);
      await configRepo.setLetztesDatum(DateTime.now());
      await configRepo.setPfad(Directory.systemTemp.path);

      final ausgefuehrt = await service.pruefeUndStarteAutoBackup();

      expect(ausgefuehrt, isFalse);
    });

    test('wirft keine Exceptions bei fehlgeschlagenem Backup', () async {
      await configRepo.setAutoAktiv(true);
      await configRepo.setIntervall(1);
      // Pfad zeigt auf eine Datei (kein Verzeichnis) → Fehler beim Anlegen.
      await configRepo.setPfad('/dev/null/unmoeglich');

      final ausgefuehrt = await service.pruefeUndStarteAutoBackup();

      expect(ausgefuehrt, isFalse);
    });
  });

  group('restore', () {
    test('wirft Exception bei nicht existierender Quelldatei', () async {
      await expectLater(
        service.restore('/does/not/exist.sqlite'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
