import 'dart:io';

import '../database/database.dart';

/// Service für Datenbank-Backup und -Restore.
///
/// Backup: WAL-Checkpoint + File.copy
/// Restore: DB schließen → Datei ersetzen → DB neu öffnen
///
/// Dieser Service ist bewusst KEIN Riverpod-Provider, da beim Restore
/// der appDatabaseProvider invalidiert wird, was alle abhängigen Provider
/// disposed. Stattdessen werden Abhängigkeiten direkt übergeben.
class DatabaseBackupService {
  DatabaseBackupService._();

  /// Erstellt ein Backup der Datenbankdatei am angegebenen Zielort.
  ///
  /// Ablauf:
  /// 1. WAL-Checkpoint (schreibt Cache in Hauptdatei)
  /// 2. Datei kopieren
  static Future<void> backup(AppDatabase db, String targetPath) async {
    await db.checkpoint();
    await File(AppDatabase.dbFilePath).copy(targetPath);
  }

  /// Stellt die Datenbank aus einer Backup-Datei wieder her.
  ///
  /// Ablauf:
  /// 1. Aktuelle DB als .bak sichern (Sicherheitsnetz)
  /// 2. DB-Verbindung schließen
  /// 3. Backup-Datei über aktuelle DB kopieren
  /// 4. Bei Fehler: .bak zurückspielen
  ///
  /// Nach dem Aufruf muss der appDatabaseProvider invalidiert werden,
  /// um die DB neu zu öffnen.
  static Future<void> restore(AppDatabase db, String sourcePath) async {
    final dbPath = AppDatabase.dbFilePath;
    final bakPath = '$dbPath.bak';

    // 1. Sicherheitskopie der aktuellen DB
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      await dbFile.copy(bakPath);
    }

    // 2. DB schließen
    await db.close();

    // Kurz warten bis die Verbindung geschlossen ist
    await Future<void>.delayed(const Duration(milliseconds: 500));

    try {
      // 3. Backup-Datei über aktuelle DB kopieren
      final sourceFile = File(sourcePath);
      await sourceFile.copy(dbPath);
    } catch (e) {
      // 4. Bei Fehler: Sicherheitskopie zurückspielen
      final bakFile = File(bakPath);
      if (await bakFile.exists()) {
        await bakFile.copy(dbPath);
      }
      rethrow;
    } finally {
      // Sicherheitskopie aufräumen
      final bakFile = File(bakPath);
      if (await bakFile.exists()) {
        await bakFile.delete();
      }
    }
  }

  /// Gibt den Standard-Dateinamen für ein Backup zurück.
  /// Format: clup_data_backup_YYYY-MM-DD_HH-MM.sqlite
  static String defaultBackupFileName() {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final time =
        '${now.hour.toString().padLeft(2, '0')}-'
        '${now.minute.toString().padLeft(2, '0')}';
    return 'clup_data_backup_${date}_$time.sqlite';
  }

  /// Prüft ob eine Datei eine gültige SQLite-Datenbank ist.
  static Future<bool> isValidSqliteFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final header = await file.openRead(0, 16).first;
    if (header.length < 16) return false;
    // SQLite-Header beginnt mit "SQLite format 3\000"
    const sqliteHeader = [
      83,
      81,
      76,
      105,
      116,
      101,
      32,
      102,
      111,
      114,
      109,
      97,
      116,
      32,
      51,
      0,
    ];
    for (var i = 0; i < 16; i++) {
      if (header[i] != sqliteHeader[i]) return false;
    }
    return true;
  }
}
