import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/backup_config_repository.dart';
import '../../data/backup_verzeichnis_service.dart';
import '../../domain/models/auto_backup_status_state.dart';
import '../../domain/models/backup_config.dart';
import '../../domain/models/backup_eintrag.dart';
import '../../services/backup_scheduler_service.dart';

part 'backup_providers.g.dart';

/// Backup-Konfiguration (Stammdaten).
@riverpod
Future<BackupConfig> backupConfig(Ref ref) async {
  final repo = ref.watch(backupConfigRepositoryProvider);
  return repo.loadConfig();
}

/// Vorhandene Sicherungen im konfigurierten Auto-Verzeichnis.
@riverpod
Future<List<BackupEintrag>> backupEintraege(Ref ref) async {
  final config = await ref.watch(backupConfigProvider.future);
  return const BackupVerzeichnisService().ladeBackups(config.pfad);
}

/// Status und Ausführung des Backup-Tasks (Hintergrund, nicht blockierend).
@riverpod
class AutoBackupStatus extends _$AutoBackupStatus {
  @override
  AutoBackupStatusState build() => const AutoBackupStatusState.idle();

  /// Startet das Auto-Backup, wenn das Intervall überschritten ist.
  ///
  /// Für den Aufruf beim App-Start: wirft keine Exceptions, aktualisiert
  /// bei Erfolg die abhängigen Provider.
  Future<void> starteWennFaellig() async {
    final configRepo = ref.read(backupConfigRepositoryProvider);
    try {
      final config = await configRepo.loadConfig();
      if (!config.istFaellig(DateTime.now())) return;
      if (config.pfad.trim().isEmpty) return;
      await fuehreBackupAus(config.pfad);
    } catch (_) {
      // Auto-Backup darf die Anwendung niemals stören.
    }
  }

  /// Führt ein Backup nach [zielVerzeichnis] aus (manuell oder automatisch).
  ///
  /// Rückgabe: der erstellte [BackupEintrag] oder `null` bei Fehler.
  Future<BackupEintrag?> fuehreBackupAus(String zielVerzeichnis) async {
    state = const AutoBackupStatusState.running();
    try {
      final scheduler = ref.read(backupSchedulerProvider);
      final eintrag = await scheduler.backup(zielVerzeichnis: zielVerzeichnis);
      state = AutoBackupStatusState.success(eintrag.erstelltAm);
      ref.invalidate(backupConfigProvider);
      ref.invalidate(backupEintraegeProvider);
      return eintrag;
    } catch (e) {
      state = AutoBackupStatusState.error('$e');
      return null;
    }
  }

  /// Setzt den Status auf „Bereit" zurück (z. B. nach Meldungs-Anzeige).
  void zuruecksetzen() => state = const AutoBackupStatusState.idle();
}
