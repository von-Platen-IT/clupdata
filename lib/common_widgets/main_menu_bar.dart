import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/providers/data_grid_meta_state_provider.dart';
import '../core/providers/database_provider.dart';
import '../core/providers/export_data_repository_provider.dart';
import '../features/export/domain/batch_export_config.dart';
import '../features/export/presentation/batch_export_config_dialog.dart';
import '../features/export/services/batch_export_service.dart';
import '../features/members/widgets/member_edit_dialog.dart';
import '../features/leistungen/widgets/leistung_edit_dialog.dart';
import '../features/waren/widgets/waren_edit_dialog.dart';
import '../features/beitraege/presentation/dialogs/rechnungslegung_dialog.dart';

class MainMenuBar extends ConsumerWidget {
  const MainMenuBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          _MenuButton(
            title: 'Datei',
            items: [
              PopupMenuItem(child: const Text('Einstellungen'), onTap: () {}),
              const PopupMenuDivider(),
              PopupMenuItem(
                child: const Text('Beenden'),
                onTap: () {
                  exit(0);
                },
              ),
            ],
          ),
          _MenuButton(
            title: 'Erstellen',
            items: [
              PopupMenuItem(
                child: const Text('Mitglied'),
                onTap: () {
                  MemberEditDialog.show(context);
                },
              ),
              PopupMenuItem(
                child: const Text('Leistung'),
                onTap: () {
                  LeistungEditDialog.show(context);
                },
              ),
              PopupMenuItem(
                child: const Text('Ware'),
                onTap: () {
                  WarenEditDialog.show(context);
                },
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                child: const Text('Rechnungslegung'),
                onTap: () {
                  RechnungslegungDialog.show(context);
                },
              ),
            ],
          ),
          _MenuButton(
            title: 'Exportieren',
            items: [
              PopupMenuItem(
                child: const Text('Mitglieder exportieren...'),
                onTap: () {
                  _handleBatchExport(context, ref, 'mitglied', 'Mitglieder');
                },
              ),
              PopupMenuItem(
                child: const Text('Rechnungen exportieren...'),
                onTap: () {
                  _handleBatchExport(context, ref, 'rechnung', 'Rechnungen');
                },
              ),
              PopupMenuItem(
                child: const Text('Beiträge exportieren...'),
                onTap: () {
                  _handleBatchExport(context, ref, 'beitrag', 'Beiträge');
                },
              ),
              PopupMenuItem(
                child: const Text('Leistungen exportieren...'),
                onTap: () {
                  _handleBatchExport(context, ref, 'leistung', 'Leistungen');
                },
              ),
              PopupMenuItem(
                child: const Text('Waren exportieren...'),
                onTap: () {
                  _handleBatchExport(context, ref, 'ware', 'Waren');
                },
              ),
            ],
          ),
          _MenuButton(
            title: 'Hilfe',
            items: [
              PopupMenuItem(
                child: const Text('Über die App'),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'ClupData',
                    applicationVersion: '1.0.0',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleBatchExport(
    BuildContext context,
    WidgetRef ref,
    String entityType,
    String entityDisplayName,
  ) async {
    final metaStateMap = ref.read(dataGridMetaStateProvider);
    final metaState = metaStateMap[entityType];

    if (metaState == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Keine Daten für "$entityDisplayName" verfügbar. '
              'Bitte öffnen Sie zuerst die entsprechende Ansicht.',
            ),
          ),
        );
      }
      return;
    }

    final estimatedCount = metaState.allColumns.isNotEmpty ? 100 : 0;

    final config = await BatchExportConfigDialog.show(
      context,
      entityType: entityType,
      entityDisplayName: entityDisplayName,
      metaState: metaState,
      estimatedItemCount: estimatedCount,
    );

    if (config != null && context.mounted) {
      final repository = ref.read(exportDataRepositoryProvider);
      final database = ref.read(appDatabaseProvider);
      final exportService = BatchExportService(
        repository: repository,
        db: database,
      );

      await _showExportProgressDialog(
        context,
        exportService,
        config,
        entityDisplayName,
      );
    }
  }

  Future<void> _showExportProgressDialog(
    BuildContext context,
    BatchExportService exportService,
    BatchExportConfig config,
    String entityDisplayName,
  ) async {
    int progress = 0;
    int total = 0;
    bool isComplete = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (total == 0 && !isComplete && errorMessage == null) {
              total = 1;

              Future.microtask(() async {
                try {
                  final result = await exportService.execute(
                    config: config,
                    onProgress: (current, totalItems) {
                      setDialogState(() {
                        progress = current;
                        total = totalItems;
                      });
                    },
                  );

                  setDialogState(() {
                    isComplete = true;
                    if (result.hasErrors) {
                      errorMessage = '${result.errorCount} Fehler aufgetreten';
                    }
                  });
                } catch (e) {
                  setDialogState(() {
                    isComplete = true;
                    errorMessage = e.toString();
                  });
                }
              });
            }

            return AlertDialog(
              title: Text(isComplete ? 'Export abgeschlossen' : 'Export läuft...'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Exportiere $entityDisplayName...'),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: total > 0 ? progress / total : null,
                  ),
                  const SizedBox(height: 8),
                  Text('$progress / $total'),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  if (isComplete) ...[
                    const SizedBox(height: 8),
                    const Text('Export erfolgreich abgeschlossen.'),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isComplete ? () => Navigator.pop(dialogContext) : null,
                  child: const Text('Schließen'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final List<PopupMenuEntry<dynamic>> items;

  const _MenuButton({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.black12,
      ),
      child: PopupMenuButton(
        offset: const Offset(0, 30),
        tooltip: '',
        itemBuilder: (context) => items,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
