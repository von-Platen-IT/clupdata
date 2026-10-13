import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/models/backup_eintrag.dart';

/// Scannt das Backup-Verzeichnis und liefert die vorhandenen Sicherungen.
///
/// Keine DB-Protokollierung (Hähnei-Problem, siehe ADR-003) – die Liste
/// wird aus dem Dateisystem erzeugt.
class BackupVerzeichnisService {
  const BackupVerzeichnisService();

  /// Dateipräfix aller Sicherungen (siehe
  /// `DatabaseBackupService.defaultBackupFileName`).
  static const String dateiPraefix = 'clup_data_backup';

  /// Liefert alle Backup-Dateien in [verzeichnis],
  /// sortiert nach Änderungsdatum (neueste zuerst).
  Future<List<BackupEintrag>> ladeBackups(String verzeichnis) async {
    if (verzeichnis.trim().isEmpty) return [];
    final dir = Directory(verzeichnis);
    if (!await dir.exists()) return [];

    final eintraege = <BackupEintrag>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith(dateiPraefix) || !name.endsWith('.sqlite')) {
        continue;
      }
      final stat = await entity.stat();
      eintraege.add(
        BackupEintrag(
          dateiname: name,
          pfad: entity.path,
          groesseBytes: stat.size,
          erstelltAm: stat.modified,
        ),
      );
    }
    eintraege.sort((a, b) => b.erstelltAm.compareTo(a.erstelltAm));
    return eintraege;
  }
}
