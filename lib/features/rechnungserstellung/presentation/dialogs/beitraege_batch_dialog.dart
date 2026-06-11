import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../../common_widgets/app_section_header.dart';
import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../members/data/members_repository.dart';
import '../../domain/models/batch_rechnung_result.dart';
import '../../services/beitraege_batch_service.dart';

/// Dialog for batch-generating Beiträge (contribution invoices).
///
/// Allows the user to select a year, month, and optional filters,
/// then creates `beitrag` entries for all qualifying members.
class BeitraegeBatchDialog extends HookConsumerWidget {
  const BeitraegeBatchDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const BeitraegeBatchDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'de_DE',
      symbol: '€',
    );

    // State
    final isProcessing = useState(false);
    final result = useState<BatchRechnungResult?>(null);
    final progress = useState(0);
    final totalMembers = useState(0);
    final scrollController = useScrollController();

    // Form state
    final selectedYear = useState<int>(DateTime.now().year);
    final selectedMonth = useState<int>(DateTime.now().month);
    final quartalsweise = useState(false);
    final nurAktiveVertraege = useState(true);
    final nurOhneOffene = useState(false);
    final initialStatus = useState<String>('kontiert');
    final bemerkungController = useTextEditingController(
      text: 'Beitrag durch Rechnungslegung erstellt',
    );

    // Preview state
    final previewCount = useState<int?>(null);
    final isLoadingPreview = useState(false);

    // Year options (current year and 5 years back)
    final yearOptions = useMemoized(
      () => List.generate(6, (i) => DateTime.now().year - i),
      [],
    );

    // Month options
    final monthOptions = useMemoized(() => List.generate(12, (i) => i + 1), []);

    // German month names
    final monthNames = useMemoized(
      () => {
        1: 'Januar',
        2: 'Februar',
        3: 'März',
        4: 'April',
        5: 'Mai',
        6: 'Juni',
        7: 'Juli',
        8: 'August',
        9: 'September',
        10: 'Oktober',
        11: 'November',
        12: 'Dezember',
      },
      [],
    );

    // Load preview count
    Future<void> loadPreview() async {
      isLoadingPreview.value = true;
      try {
        final db = ref.read(appDatabaseProvider);
        final service = BeitraegeBatchService(db);
        var members = await service.loadMembersWithContracts(
          nurAktiveVertraege: nurAktiveVertraege.value,
        );
        previewCount.value = members.length;
      } catch (_) {
        previewCount.value = null;
      } finally {
        isLoadingPreview.value = false;
      }
    }

    // Load preview when filters change
    useEffect(() {
      loadPreview();
      return null;
    }, [nurAktiveVertraege.value]);

    // Handle the generation process
    Future<void> startBatch() async {
      isProcessing.value = true;
      progress.value = 0;
      totalMembers.value = 0;
      result.value = null;

      try {
        final db = ref.read(appDatabaseProvider);
        final service = BeitraegeBatchService(db);

        final config = BeitraegeBatchConfig(
          year: selectedYear.value,
          month: selectedMonth.value,
          nurAktiveVertraege: nurAktiveVertraege.value,
          nurOhneOffene: nurOhneOffene.value,
          initialStatus: initialStatus.value,
          bemerkung: bemerkungController.text.trim(),
          quartalsweise: quartalsweise.value,
        );

        final batchResult = await service.run(config);
        result.value = batchResult;

        // Invalidate providers to refresh data
        ref.invalidate(membersRepositoryProvider);

        // Auto-scroll to result
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler bei der Rechnungslegung: $e')),
          );
        }
      } finally {
        isProcessing.value = false;
      }
    }

    // Build result details dialog
    void showResultDetails() {
      final res = result.value;
      if (res == null || res.erstellteRechnungen.isEmpty) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Erstellte Beiträge'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: res.erstellteRechnungen.length,
                    itemBuilder: (context, index) {
                      final eintrag = res.erstellteRechnungen[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          '${eintrag.rechnungsnummer}  ${eintrag.kundeName}',
                        ),
                        trailing: Text(
                          currencyFormatter.format(eintrag.betragBrutto),
                        ),
                      );
                    },
                  ),
                ),
                const Gap(8),
                Text(
                  'Gesamt: ${currencyFormatter.format(res.gesamtBetragBrutto)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schließen'),
            ),
          ],
        ),
      );
    }

    // ── Result state ──────────────────────────────────────────────────────

    if (result.value != null) {
      final res = result.value!;
      final hasErrors = res.hasErrors;

      return AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Beitrags-Rechnungen'),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Schließen',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Gap(24),
              Icon(
                hasErrors ? Icons.warning_amber : Icons.check_circle,
                size: 64,
                color: hasErrors ? Colors.orange : Colors.green,
              ),
              const Gap(16),
              Text(
                hasErrors
                    ? 'Rechnungslegung mit Fehlern abgeschlossen'
                    : 'Rechnungslegung erfolgreich',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const Gap(24),
              _resultRow('Erstellt:', '${res.successCount}'),
              _resultRow('Übersprungen:', '${res.skippedCount}'),
              if (res.erstellteRechnungen.isNotEmpty)
                _resultRow(
                  'Gesamtbetrag:',
                  currencyFormatter.format(res.gesamtBetragBrutto),
                ),
              if (hasErrors) _resultRow('Fehler:', '${res.errors.length}'),
              const Gap(24),
              if (res.erstellteRechnungen.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: showResultDetails,
                  icon: const Icon(Icons.list),
                  label: const Text('Details anzeigen'),
                ),
              const Gap(24),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      );
    }

    // ── Processing state ──────────────────────────────────────────────────

    if (isProcessing.value) {
      final percentage = totalMembers.value > 0
          ? (progress.value / totalMembers.value * 100).toInt()
          : 0;

      return AppEditDialogScaffold(
        title: 'Beitrags-Rechnungen erstellen',
        isSaving: true,
        onSave: () {},
        contentWidth: 450,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(32),
            const CircularProgressIndicator(),
            const Gap(24),
            const Text(
              'Beiträge werden erstellt...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const Gap(16),
            Text('${progress.value} von ${totalMembers.value} ($percentage%)'),
            const Gap(16),
            LinearProgressIndicator(
              value: totalMembers.value > 0
                  ? progress.value / totalMembers.value
                  : null,
            ),
            const Gap(32),
          ],
        ),
      );
    }

    // ── Input state ───────────────────────────────────────────────────────

    return AppEditDialogScaffold(
      title: 'Beitrags-Rechnungen erstellen',
      contentWidth: 450,
      isSaving: false,
      onSave: startBatch,
      content: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Abrechnungszeitraum
            const AppSectionHeader('Abrechnungszeitraum'),
            const Gap(8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: selectedYear.value,
                    decoration: const InputDecoration(
                      labelText: 'Jahr',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: yearOptions.map((year) {
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) selectedYear.value = v;
                    },
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: selectedMonth.value,
                    decoration: const InputDecoration(
                      labelText: 'Monat',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: monthOptions.map((month) {
                      return DropdownMenuItem(
                        value: month,
                        child: Text(monthNames[month]!),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) selectedMonth.value = v;
                    },
                  ),
                ),
              ],
            ),
            const Gap(8),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Quartalsweise abrechnen'),
              subtitle: const Text(
                'Erstellt Beiträge für 3 Monate gleichzeitig',
              ),
              value: quartalsweise.value,
              onChanged: (v) => quartalsweise.value = v ?? false,
            ),
            const Gap(16),

            // Filter
            const AppSectionHeader('Filter'),
            const Gap(8),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Nur aktive Verträge'),
              subtitle: const Text('Nur Mitglieder mit Laufzeit bis >= heute'),
              value: nurAktiveVertraege.value,
              onChanged: (v) => nurAktiveVertraege.value = v ?? true,
            ),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Nur ohne offene Beiträge'),
              subtitle: const Text(
                'Überspringt Mitglieder mit offenen/kontierten Beiträgen',
              ),
              value: nurOhneOffene.value,
              onChanged: (v) => nurOhneOffene.value = v ?? false,
            ),
            const Gap(16),

            // Optionen
            const AppSectionHeader('Optionen'),
            const Gap(8),
            const Text('Status nach Erstellung:'),
            const Gap(4),
            RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Kontiert (Standard)'),
              subtitle: const Text(
                'Beitrag wird angelegt, aber noch nicht als zahlbar markiert',
              ),
              value: 'kontiert',
              groupValue: initialStatus.value,
              onChanged: (v) {
                if (v != null) initialStatus.value = v;
              },
            ),
            RadioListTile<String>(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Offen (direkt zahlbar)'),
              subtitle: const Text('Beitrag wird als fällig markiert'),
              value: 'offen',
              groupValue: initialStatus.value,
              onChanged: (v) {
                if (v != null) initialStatus.value = v;
              },
            ),
            const Gap(8),
            AppTextField(
              controller: bemerkungController,
              label: 'Bemerkung (optional)',
            ),
            const Gap(16),

            // Vorschau
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withAlpha(77)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const Gap(8),
                  Expanded(
                    child: Text(
                      isLoadingPreview.value
                          ? 'Lade Vorschau...'
                          : 'Betroffene Mitglieder: ${previewCount.value ?? '–'}',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(16),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
