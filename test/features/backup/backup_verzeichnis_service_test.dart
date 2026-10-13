import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:clupdata/features/backup/data/backup_verzeichnis_service.dart';
import 'package:clupdata/features/backup/domain/models/backup_eintrag.dart';

void main() {
  const service = BackupVerzeichnisService();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> schreibeDatei(String name, {int groesse = 100}) async {
    final file = File('${tempDir.path}/$name');
    await file.writeAsBytes(List.filled(groesse, 42));
    return file;
  }

  group('ladeBackups', () {
    test('findet Backup-Dateien, ignoriert Fremddateien', () async {
      await schreibeDatei('clup_data_backup_2026-10-12_08-30.sqlite');
      await schreibeDatei('clup_data_backup_2026-10-05_08-30.sqlite');
      await schreibeDatei('notiz.txt');
      await schreibeDatei('andere.sqlite');

      final backups = await service.ladeBackups(tempDir.path);

      expect(backups, hasLength(2));
      expect(
        backups.every((b) => b.dateiname.startsWith('clup_data_backup')),
        isTrue,
      );
    });

    test('sortiert nach Datum (neueste zuerst)', () async {
      final aelteste = await schreibeDatei(
        'clup_data_backup_2026-10-01_08-30.sqlite',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final neueste = await schreibeDatei(
        'clup_data_backup_2026-10-12_08-30.sqlite',
      );
      // Zeitstempel gezielt setzen (Reihenfolge eindeutig).
      await aelteste.setLastModified(DateTime(2026, 10, 1));
      await neueste.setLastModified(DateTime(2026, 10, 12));

      final backups = await service.ladeBackups(tempDir.path);

      expect(
        backups.first.dateiname,
        'clup_data_backup_2026-10-12_08-30.sqlite',
      );
      expect(
        backups.last.dateiname,
        'clup_data_backup_2026-10-01_08-30.sqlite',
      );
    });

    test('liefert Dateigröße und Änderungsdatum', () async {
      await schreibeDatei('clup_data_backup_x.sqlite', groesse: 2048);

      final backups = await service.ladeBackups(tempDir.path);

      expect(backups.single.groesseBytes, 2048);
      expect(backups.single.erstelltAm, isNotNull);
      expect(backups.single.pfad, contains('clup_data_backup_x.sqlite'));
    });

    test('leeres Verzeichnis liefert leere Liste', () async {
      expect(await service.ladeBackups(tempDir.path), isEmpty);
    });

    test('fehlendes Verzeichnis liefert leere Liste', () async {
      expect(
        await service.ladeBackups('${tempDir.path}/gibt_es_nicht'),
        isEmpty,
      );
    });

    test('leerer Pfad liefert leere Liste', () async {
      expect(await service.ladeBackups(''), isEmpty);
      expect(await service.ladeBackups('   '), isEmpty);
    });
  });

  group('BackupEintrag.groesseAnzeige', () {
    test('formatiert deutsche Größenangaben', () {
      final klein = BackupEintrag(
        dateiname: 'a',
        pfad: '/a',
        groesseBytes: 512,
        erstelltAm: DateTime(2026),
      );
      final kilo = BackupEintrag(
        dateiname: 'b',
        pfad: '/b',
        groesseBytes: 2048,
        erstelltAm: DateTime(2026),
      );
      final mega = BackupEintrag(
        dateiname: 'c',
        pfad: '/c',
        groesseBytes: 3 * 1024 * 1024,
        erstelltAm: DateTime(2026),
      );

      expect(klein.groesseAnzeige, '512 B');
      expect(kilo.groesseAnzeige, '2,0 KB');
      expect(mega.groesseAnzeige, '3,0 MB');
    });
  });
}
