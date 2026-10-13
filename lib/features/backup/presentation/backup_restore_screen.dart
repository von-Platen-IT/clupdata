import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/data/database_backup_service.dart';
import '../../../core/providers/database_provider.dart';
import '../data/backup_config_repository.dart';
import '../services/backup_scheduler_service.dart';
import 'providers/backup_providers.dart';
import 'widgets/backup_liste.dart';
import 'widgets/backup_status_card.dart';

/// Eigener UI-Bereich „Sicherung & Wiederherstellung".
///
/// Manuelles Backup mit Verzeichniswahl, automatische Sicherung mit
/// konfigurierbarem Intervall (Tage) und Verzeichnis, Liste der vorhandenen
/// Sicherungen mit Wiederherstellung. Siehe `plans/backup-konzept.md`.
class BackupRestoreScreen extends HookConsumerWidget {
  const BackupRestoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(backupConfigProvider);
    final configRepo = ref.read(backupConfigRepositoryProvider);
    final intervallController = useTextEditingController(
      text: '${configAsync.value?.intervallTage ?? 7}',
    );
    final pfadController = useTextEditingController(
      text: configAsync.value?.pfad ?? '',
    );

    // Controller mit extern geänderten Werten synchronisieren.
    useEffect(() {
      final config = configAsync.value;
      if (config != null) {
        if (intervallController.text != '${config.intervallTage}') {
          intervallController.text = '${config.intervallTage}';
        }
        if (pfadController.text != config.pfad) {
          pfadController.text = config.pfad;
        }
      }
      return null;
    }, [configAsync.value]);

    Future<void> zeigeMeldung(String text, {bool fehler = false}) async {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: fehler ? Theme.of(context).colorScheme.error : null,
        ),
      );
    }

    /// Manuelles Backup mit frei wählbarem Zielverzeichnis.
    Future<void> backupManuell() async {
      final ziel = await FilePicker.platform.saveFile(
        dialogTitle: 'Backup speichern',
        fileName: DatabaseBackupService.defaultBackupFileName(),
      );
      if (ziel == null) return;
      final eintrag = await ref
          .read(autoBackupStatusProvider.notifier)
          .fuehreBackupAus(ziel);
      if (eintrag != null) {
        await zeigeMeldung('Backup erstellt: ${eintrag.dateiname}');
      } else {
        await zeigeMeldung('Backup fehlgeschlagen.', fehler: true);
      }
    }

    /// Sofortiges Backup in das konfigurierte Auto-Verzeichnis.
    Future<void> backupAuto() async {
      final pfad = configAsync.value?.pfad.trim() ?? '';
      if (pfad.isEmpty) {
        await zeigeMeldung(
          'Bitte zuerst ein Auto-Verzeichnis konfigurieren.',
          fehler: true,
        );
        return;
      }
      final eintrag = await ref
          .read(autoBackupStatusProvider.notifier)
          .fuehreBackupAus(pfad);
      if (eintrag != null) {
        await zeigeMeldung('Backup erstellt: ${eintrag.dateiname}');
      } else {
        await zeigeMeldung('Backup fehlgeschlagen.', fehler: true);
      }
    }

    /// Wiederherstellung mit Bestätigungsdialog und Neustart-Hinweis.
    Future<void> restore(String pfad) async {
      final bestaetigt = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Datenbank wiederherstellen?'),
          content: const Text(
            'Alle aktuellen Daten werden durch die gewählte Sicherung '
            'ersetzt.\n\nEine Sicherheitskopie der aktuellen Datenbank wird '
            'automatisch erstellt.\n\nBitte starten Sie die Anwendung nach '
            'der Wiederherstellung neu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Wiederherstellen'),
            ),
          ],
        ),
      );
      if (bestaetigt != true) return;

      try {
        await ref.read(backupSchedulerProvider).restore(pfad);
        ref.invalidate(appDatabaseProvider);
        await zeigeMeldung(
          'Wiederherstellung abgeschlossen. '
          'Bitte starten Sie die Anwendung neu.',
        );
      } catch (e) {
        await zeigeMeldung(
          'Wiederherstellung fehlgeschlagen: $e',
          fehler: true,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sicherung & Wiederherstellung')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BackupStatusCard(),
            const Gap(16),
            // Sofort-Aktionen
            Row(
              children: [
                FilledButton.icon(
                  onPressed: backupManuell,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Jetzt sichern…'),
                ),
                const Gap(8),
                OutlinedButton.icon(
                  onPressed: backupAuto,
                  icon: const Icon(Icons.folder_copy),
                  label: const Text('In Auto-Verzeichnis sichern'),
                ),
              ],
            ),
            const Gap(24),
            // Konfiguration
            Text(
              'Automatische Datensicherung',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Gap(8),
            CheckboxListTile(
              value: configAsync.value?.autoAktiv ?? true,
              onChanged: (v) async {
                await configRepo.setAutoAktiv(v ?? true);
                ref.invalidate(backupConfigProvider);
              },
              title: const Text('Beim Programmstart automatisch sichern'),
              contentPadding: EdgeInsets.zero,
            ),
            const Gap(8),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: intervallController,
                    decoration: const InputDecoration(
                      labelText: 'Intervall (Tage)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onSubmitted: (t) async {
                      final tage = int.tryParse(t);
                      if (tage != null && tage >= 1) {
                        await configRepo.setIntervall(tage);
                        ref.invalidate(backupConfigProvider);
                      }
                    },
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: TextField(
                    controller: pfadController,
                    decoration: const InputDecoration(
                      labelText: 'Auto-Verzeichnis',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    readOnly: true,
                  ),
                ),
                const Gap(8),
                OutlinedButton(
                  onPressed: () async {
                    final verzeichnis = await FilePicker.platform
                        .getDirectoryPath(
                          dialogTitle: 'Backup-Verzeichnis wählen',
                        );
                    if (verzeichnis != null) {
                      await configRepo.setPfad(verzeichnis);
                      ref.invalidate(backupConfigProvider);
                      ref.invalidate(backupEintraegeProvider);
                    }
                  },
                  child: const Text('Ändern…'),
                ),
              ],
            ),
            const Gap(8),
            Text(
              'Das Intervall legt fest, nach wie vielen Tagen beim Programmstart '
              'automatisch eine Sicherung erstellt wird.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Gap(24),
            // Backup-Liste + Restore
            BackupListe(onRestore: (eintrag) => restore(eintrag.pfad)),
            const Gap(8),
            OutlinedButton.icon(
              onPressed: () async {
                final datei = await FilePicker.platform.pickFiles(
                  dialogTitle: 'Backup-Datei wählen',
                  type: FileType.any,
                );
                final pfad = datei?.files.single.path;
                if (pfad != null) {
                  if (await DatabaseBackupService.isValidSqliteFile(pfad)) {
                    await restore(pfad);
                  } else {
                    await zeigeMeldung(
                      'Die gewählte Datei ist keine gültige SQLite-Datenbank.',
                      fehler: true,
                    );
                  }
                }
              },
              icon: const Icon(Icons.file_open),
              label: const Text('Aus Datei wiederherstellen…'),
            ),
          ],
        ),
      ),
    );
  }
}
