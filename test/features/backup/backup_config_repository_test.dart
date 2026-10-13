import 'dart:ffi';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

import 'package:clupdata/core/database/database.dart';
import 'package:clupdata/features/backup/data/backup_config_repository.dart';

void main() {
  late AppDatabase db;
  late BackupConfigRepository repo;

  setUpAll(() {
    // Linux-Systeme haben oft nur libsqlite3.so.0 (ohne Dev-Link .so).
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BackupConfigRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('loadConfig', () {
    test('legt fehlende Schlüssel mit Standard-Werten an', () async {
      final config = await repo.loadConfig();

      expect(config.pfad, '');
      expect(config.intervallTage, 7);
      expect(config.autoAktiv, isTrue);
      expect(config.letztesDatum, isNull);
    });

    test('getOrCreate ist idempotent (keine doppelten Schlüssel)', () async {
      await repo.loadConfig();
      await repo.loadConfig();

      final eintraege = await db.select(db.stammdaten).get();
      final backupSchluessel = eintraege
          .map((e) => e.schluessel)
          .where(
            (s) =>
                s == BackupConfigRepository.schluesselIntervall ||
                s == BackupConfigRepository.schluesselAutoAktiv ||
                s == BackupConfigRepository.schluesselLetztesDatum,
          );
      expect(backupSchluessel, hasLength(3));
    });
  });

  group('Updates', () {
    test('setIntervall speichert und lädt erneut', () async {
      await repo.setIntervall(14);
      expect((await repo.loadConfig()).intervallTage, 14);
    });

    test('setIntervall erzwingt mindestens 1 Tag', () async {
      await repo.setIntervall(0);
      expect((await repo.loadConfig()).intervallTage, 1);
    });

    test('setAutoAktiv speichert und lädt erneut', () async {
      await repo.setAutoAktiv(false);
      expect((await repo.loadConfig()).autoAktiv, isFalse);

      await repo.setAutoAktiv(true);
      expect((await repo.loadConfig()).autoAktiv, isTrue);
    });

    test('setPfad speichert und lädt erneut', () async {
      await repo.setPfad('/tmp/backups');
      expect((await repo.loadConfig()).pfad, '/tmp/backups');
    });

    test('setLetztesDatum speichert und lädt erneut', () async {
      final zeitpunkt = DateTime(2026, 10, 12, 8, 30);
      await repo.setLetztesDatum(zeitpunkt);

      final config = await repo.loadConfig();
      expect(config.letztesDatum, isNotNull);
      expect(config.letztesDatum!.year, 2026);
      expect(config.letztesDatum!.month, 10);
      expect(config.letztesDatum!.day, 12);
    });
  });
}
