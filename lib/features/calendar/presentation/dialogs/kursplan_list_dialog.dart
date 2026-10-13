import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common_widgets/app_dialog_delete_action.dart';
import '../../data/kursplan_repository.dart';
import '../../domain/models/kursplan_row_data.dart';
import '../../domain/wochen_utils.dart';
import '../providers/kursplan_providers.dart';
import 'kursplan_edit_dialog.dart';

/// Verwaltungsdialog für Kurspläne: Liste, Neu, Bearbeiten, Löschen.
class KursplanListDialog extends ConsumerWidget {
  const KursplanListDialog({super.key});

  /// Opens the schedule plan management dialog.
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const KursplanListDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plaeneAsync = ref.watch(kursplaeneListProvider);

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Kurspläne verwalten'),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Schließen',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        height: 400,
        child: plaeneAsync.when(
          data: (plaene) => plaene.isEmpty
              ? const Center(child: Text('Noch keine Kurspläne angelegt.'))
              : ListView(
                  children: [
                    for (final plan in plaene)
                      // Eigene Zeile statt ListTile: ListTile.trailing ist auf
                      // 56px begrenzt, was die Aktionsbuttons beschädigt.
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month),
                            const Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                  Text(
                                    _gueltigkeitText(plan),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Bearbeiten',
                              onPressed: () =>
                                  KursplanEditDialog.show(context, plan: plan),
                            ),
                            AppDialogDeleteAction(
                              entityLabel: 'Kursplan',
                              onConfirmed: () async {
                                final repo = ref.read(
                                  kursplanRepositoryProvider,
                                );
                                await repo.deleteKursplan(plan.id);
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Fehler beim Laden: $e')),
        ),
      ),
      // Hinweis: AlertDialog.actions ist ein OverflowBar (kein Flex) –
      // ein Gap-Widget dort würde eine Layout-Exception auslösen.
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Schließen'),
        ),
        FilledButton.icon(
          onPressed: () => KursplanEditDialog.show(context),
          icon: const Icon(Icons.add),
          label: const Text('Neuer Kursplan'),
        ),
      ],
    );
  }

  /// Deutsche Anzeige des Gültigkeitszeitraums.
  String _gueltigkeitText(KursplanRowData plan) {
    final von = formatiereWochenBereich(plan.gueltigVon);
    final bis = plan.gueltigBis;
    if (bis == null) return 'Gültig ab $von (unbefristet)';
    return 'Gültig $von bis ${formatiereWochenBereich(bis)}';
  }
}
