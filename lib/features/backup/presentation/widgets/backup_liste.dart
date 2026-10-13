import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/backup_eintrag.dart';
import '../providers/backup_providers.dart';

/// Liste der vorhandenen Sicherungen im Auto-Verzeichnis.
///
/// Je Zeile: Dateiname, Erstellt am, Größe und die Aktion
/// „Wiederherstellen" (mit Bestätigungsdialog, siehe Screen).
class BackupListe extends ConsumerWidget {
  /// Callback für den Restore-Wunsch einer Datei.
  final ValueChanged<BackupEintrag> onRestore;

  const BackupListe({super.key, required this.onRestore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final eintraegeAsync = ref.watch(backupEintraegeProvider);
    final datumFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Vorhandene Sicherungen', style: theme.textTheme.titleMedium),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Liste aktualisieren',
              onPressed: () => ref.invalidate(backupEintraegeProvider),
            ),
          ],
        ),
        const Gap(8),
        eintraegeAsync.when(
          data: (eintraege) => eintraege.isEmpty
              ? const Text('Keine Sicherungen im Auto-Verzeichnis gefunden.')
              : Column(
                  children: [
                    // Tabellenkopf
                    const _KopfZeile(),
                    const Divider(height: 1),
                    for (final eintrag in eintraege)
                      _BackupZeile(
                        eintrag: eintrag,
                        datumFormat: datumFormat,
                        onRestore: () => onRestore(eintrag),
                      ),
                  ],
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Fehler beim Lesen des Verzeichnisses: $e'),
        ),
      ],
    );
  }
}

/// Spaltenüberschrift der Backup-Liste.
class _KopfZeile extends StatelessWidget {
  const _KopfZeile();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Row(
      children: [
        Expanded(flex: 4, child: Text('Datei', style: style)),
        Expanded(flex: 2, child: Text('Erstellt am', style: style)),
        SizedBox(width: 80, child: Text('Größe', style: style)),
        SizedBox(width: 150, child: Text('Aktionen', style: style)),
      ],
    );
  }
}

/// Eine Zeile der Backup-Liste.
class _BackupZeile extends StatelessWidget {
  final BackupEintrag eintrag;
  final DateFormat datumFormat;
  final VoidCallback onRestore;

  const _BackupZeile({
    required this.eintrag,
    required this.datumFormat,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            eintrag.dateiname,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(flex: 2, child: Text(datumFormat.format(eintrag.erstelltAm))),
        SizedBox(width: 80, child: Text(eintrag.groesseAnzeige)),
        SizedBox(
          width: 150,
          child: TextButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.settings_backup_restore, size: 18),
            label: const Text('Wiederherstellen'),
          ),
        ),
      ],
    );
  }
}
