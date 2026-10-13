import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/auto_backup_status_state.dart';
import '../providers/backup_providers.dart';

/// Status-Karte des Backup-Bereichs.
///
/// Zeigt letztes Backup, nächstes Fälligkeitsdatum, Auto-Verzeichnis und
/// den Live-Status des Hintergrund-Tasks (dezente Anzeige, kein Dialog).
class BackupStatusCard extends ConsumerWidget {
  const BackupStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final configAsync = ref.watch(backupConfigProvider);
    final status = ref.watch(autoBackupStatusProvider);
    final datumFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: configAsync.when(
          data: (config) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status', style: theme.textTheme.titleMedium),
              const Gap(8),
              _InfoZeile(
                label: 'Letztes Backup:',
                wert: config.letztesDatum == null
                    ? 'Noch keine Sicherung'
                    : datumFormat.format(config.letztesDatum!),
              ),
              _InfoZeile(
                label: 'Nächstes fällig:',
                wert: !config.autoAktiv
                    ? 'Automatische Sicherung deaktiviert'
                    : config.naechstesFaellig == null
                    ? 'Sofort (noch nie gesichert)'
                    : DateFormat('dd.MM.yyyy').format(config.naechstesFaellig!),
              ),
              _InfoZeile(
                label: 'Intervall:',
                wert: '${config.intervallTage} Tage',
              ),
              _InfoZeile(
                label: 'Auto-Verzeichnis:',
                wert: config.pfad.isEmpty
                    ? '(nicht konfiguriert)'
                    : config.pfad,
              ),
              const Gap(8),
              _StatusZeile(status: status),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Fehler beim Laden der Konfiguration: $e'),
        ),
      ),
    );
  }
}

/// Beschriftetes Info-Paar.
class _InfoZeile extends StatelessWidget {
  final String label;
  final String wert;

  const _InfoZeile({required this.label, required this.wert});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label)),
          Expanded(child: Text(wert)),
        ],
      ),
    );
  }
}

/// Dezente Live-Statuszeile des Backup-Tasks.
class _StatusZeile extends StatelessWidget {
  final AutoBackupStatusState status;

  const _StatusZeile({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, farbe, text) = status.when(
      idle: () => (Icons.check_circle_outline, theme.hintColor, 'Bereit'),
      running: () =>
          (Icons.sync, theme.colorScheme.primary, 'Datensicherung läuft…'),
      success: (zeitpunkt) => (
        Icons.check_circle_outline,
        Colors.green,
        'Letzte Sicherung erfolgreich',
      ),
      error: (meldung) =>
          (Icons.error_outline, theme.colorScheme.error, 'Fehler: $meldung'),
    );

    return Row(
      children: [
        Icon(icon, size: 18, color: farbe),
        const Gap(8),
        Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: farbe)),
      ],
    );
  }
}
