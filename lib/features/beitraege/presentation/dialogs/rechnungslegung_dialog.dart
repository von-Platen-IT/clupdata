import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../../core/providers/database_provider.dart';
import '../../services/rechnungslegung_service.dart';

/// Dialog for generating contribution invoices for all members.
///
/// Allows the user to select a year and month, then creates Beitrag entries
/// for all members with valid contracts who haven't been billed yet for that period.
class RechnungslegungDialog extends HookConsumerWidget {
  const RechnungslegungDialog({super.key});

  /// Static helper to open the dialog.
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RechnungslegungDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);

    // State
    final isProcessing = useState(false);
    final result = useState<RechnungslegungResult?>(null);
    final progress = useState(0);
    final totalMembers = useState(0);

    // Form state
    final selectedYear = useState<int>(DateTime.now().year);
    final selectedMonth = useState<int>(DateTime.now().month);

    // Generate year options (current year and 5 years back)
    final yearOptions = useMemoized(
      () => List.generate(6, (i) => DateTime.now().year - i),
      [],
    );

    // Month options
    final monthOptions = useMemoized(() => List.generate(12, (i) => i + 1), []);

    // German month names
    final monthNames = {
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
    };

    // Handle the generation process
    Future<void> startRechnungslegung() async {
      isProcessing.value = true;
      progress.value = 0;
      totalMembers.value = 0;

      try {
        final service = RechnungslegungService(db);
        result.value = await service.generateBeitraegeForPeriod(
          year: selectedYear.value,
          month: selectedMonth.value,
          onProgress: (processed, total) {
            progress.value = processed;
            totalMembers.value = total;
          },
        );
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

    // Show result summary in a separate dialog
    void showResultDetails() {
      final res = result.value;
      if (res == null) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rechnungslegung abgeschlossen'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResultRow('Erstellte Beiträge:', '${res.successCount}'),
                _buildResultRow('Übersprungen:', '${res.skippedCount}'),
                if (res.hasErrors) ...[
                  const Gap(16),
                  const Text(
                    'Fehler:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Gap(8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: res.errors.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '• ${res.errors[index]}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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

    // Build content based on state
    Widget buildContent() {
      if (isProcessing.value) {
        return _buildProcessingState(progress.value, totalMembers.value);
      }

      return _buildInputState(
        selectedYear: selectedYear.value,
        selectedMonth: selectedMonth.value,
        yearOptions: yearOptions,
        monthOptions: monthOptions,
        monthNames: monthNames,
        onYearChanged: (year) => selectedYear.value = year!,
        onMonthChanged: (month) => selectedMonth.value = month!,
      );
    }

    // Nach Abschluss der Rechnungslegung: Eigener Dialog mit nur einem "Schließen" Button
    if (result.value != null) {
      return AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Rechnungslegung'),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Schließen',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: _buildResultState(result.value!, showResultDetails),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      );
    }

    return AppEditDialogScaffold(
      title: 'Rechnungslegung',
      isSaving: isProcessing.value,
      onSave: isProcessing.value ? () {} : startRechnungslegung,
      contentWidth: 450,
      content: buildContent(),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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

  Widget _buildProcessingState(int progress, int total) {
    final percentage = total > 0 ? (progress / total * 100).toInt() : 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Gap(32),
        const CircularProgressIndicator(),
        const Gap(24),
        Text(
          'Beiträge werden erstellt...',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const Gap(16),
        Text('$progress von $total Mitgliedern ($percentage%)'),
        const Gap(16),
        LinearProgressIndicator(value: total > 0 ? progress / total : null),
        const Gap(32),
      ],
    );
  }

  Widget _buildResultState(
    RechnungslegungResult result,
    VoidCallback onShowDetails,
  ) {
    final hasErrors = result.hasErrors;
    final icon = hasErrors ? Icons.warning_amber : Icons.check_circle;
    final color = hasErrors ? Colors.orange : Colors.green;
    final title = hasErrors
        ? 'Rechnungslegung mit Fehlern abgeschlossen'
        : 'Rechnungslegung erfolgreich';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Gap(24),
        Icon(icon, size: 64, color: color),
        const Gap(16),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const Gap(24),
        _buildResultRow('Erstellt:', '${result.successCount}'),
        _buildResultRow('Übersprungen:', '${result.skippedCount}'),
        if (hasErrors) _buildResultRow('Fehler:', '${result.errors.length}'),
        const Gap(24),
        if (hasErrors)
          ElevatedButton.icon(
            onPressed: onShowDetails,
            icon: const Icon(Icons.error_outline),
            label: const Text('Details anzeigen'),
          ),
        const Gap(24),
      ],
    );
  }

  Widget _buildInputState({
    required int selectedYear,
    required int selectedMonth,
    required List<int> yearOptions,
    required List<int> monthOptions,
    required Map<int, String> monthNames,
    required Function(int?) onYearChanged,
    required Function(int?) onMonthChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(8),
        const Text(
          'Wählen Sie das Jahr und den Monat für die Rechnungslegung:',
          style: TextStyle(fontSize: 14),
        ),
        const Gap(24),

        // Year selection
        DropdownButtonFormField<int>(
          initialValue: selectedYear,
          decoration: const InputDecoration(
            labelText: 'Jahr',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: yearOptions.map((year) {
            return DropdownMenuItem(value: year, child: Text(year.toString()));
          }).toList(),
          onChanged: onYearChanged,
        ),
        const Gap(16),

        // Month selection
        DropdownButtonFormField<int>(
          initialValue: selectedMonth,
          decoration: const InputDecoration(
            labelText: 'Monat',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: monthOptions.map((month) {
            return DropdownMenuItem(
              value: month,
              child: Text(monthNames[month]!),
            );
          }).toList(),
          onChanged: onMonthChanged,
        ),
        const Gap(32),

        // Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withAlpha(77)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              Gap(8),
              Expanded(
                child: Text(
                  'Es werden Beiträge für alle Mitglieder mit gültigem Vertrag erstellt. '
                  'Mitglieder, die für den gewählten Zeitraum bereits einen Beitrag haben, werden übersprungen.',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
        const Gap(16),
      ],
    );
  }
}
