import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/data/database_backup_service.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../data/backup_config_repository.dart';
import '../domain/models/backup_eintrag.dart';

part 'backup_scheduler_service.g.dart';

/// Koordiniert manuelle und automatische Datensicherungen.
///
/// Facade über [DatabaseBackupService] (WAL-Checkpoint + Datei-Kopie) und
/// [BackupConfigRepository] (Intervall, Zeitstempel). Siehe
/// `plans/backup-konzept.md`.
class BackupSchedulerService {
  final AppDatabase db;
  final BackupConfigRepository configRepo;

  BackupSchedulerService(this.db, this.configRepo);

  /// Prüft das Intervall und startet ggf. ein Hintergrund-Backup.
  ///
  /// Läuft asynchron (reines Datei-IO), blockiert die UI nicht und wirft
  /// KEINE Exceptions – Fehler werden als `false` gemeldet.
  /// Rückgabe: `true`, wenn ein Backup ausgeführt wurde.
  Future<bool> pruefeUndStarteAutoBackup() async {
    try {
      final config = await configRepo.loadConfig();
      if (!config.istFaellig(DateTime.now())) return false;
      if (config.pfad.trim().isEmpty) return false;
      await backup(zielVerzeichnis: config.pfad);
      return true;
    } catch (_) {
      // Auto-Backup darf die Anwendung niemals stören.
      return false;
    }
  }

  /// Erstellt ein Backup in [zielVerzeichnis] und setzt den Zeitstempel.
  ///
  /// Ablauf: Verzeichnis anlegen → WAL-Checkpoint → Datei-Kopie
  /// (siehe [DatabaseBackupService.backup]).
  Future<BackupEintrag> backup({required String zielVerzeichnis}) async {
    await Directory(zielVerzeichnis).create(recursive: true);
    final dateiname = DatabaseBackupService.defaultBackupFileName();
    final zielPfad = p.join(zielVerzeichnis, dateiname);

    await DatabaseBackupService.backup(db, zielPfad);
    await configRepo.setLetztesDatum(DateTime.now());

    final stat = await File(zielPfad).stat();
    return BackupEintrag(
      dateiname: dateiname,
      pfad: zielPfad,
      groesseBytes: stat.size,
      erstelltAm: stat.modified,
    );
  }

  /// Stellt eine Sicherung wieder her (inkl. Sicherheitskopie `.bak`
  /// und Rollback bei Fehler, siehe [DatabaseBackupService.restore]).
  ///
  /// Nach dem Aufruf muss der `appDatabaseProvider` invalidiert werden.
  Future<void> restore(String quellPfad) {
    return DatabaseBackupService.restore(db, quellPfad);
  }
}

/// Riverpod provider for [BackupSchedulerService].
@riverpod
BackupSchedulerService backupScheduler(Ref ref) {
  return BackupSchedulerService(
    ref.watch(appDatabaseProvider),
    ref.watch(backupConfigRepositoryProvider),
  );
}
