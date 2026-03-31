import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../../common_widgets/app_section_header.dart';
import '../../../../common_widgets/forms/app_date_picker_field.dart';
import '../../../../common_widgets/forms/app_dropdown_field.dart';
import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../core/database/database.dart';
import '../data/rechnungen_repository.dart';
import '../utils/rechnung_status_colors.dart';
import '../../export/domain/export_config.dart';

/// Valid status values for a [Rechnung].
const kRechnungStatusValues = ['offen', 'bezahlt', 'storniert'];

/// Modal dialog for editing a [Rechnung] record.
/// Opens with double-click on a row in the Rechnungen data grid.
class RechnungEditDialog extends HookConsumerWidget {
  /// ID of the [Rechnung] to edit.
  final int rechnungId;

  /// The column field that was double-clicked; used to set initial focus.
  final String? initialFocusField;

  const RechnungEditDialog({
    super.key,
    required this.rechnungId,
    this.initialFocusField,
  });

  /// Static helper to open the dialog.
  static Future<void> show(
    BuildContext context, {
    required int rechnungId,
    String? initialFocusField,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RechnungEditDialog(
        rechnungId: rechnungId,
        initialFocusField: initialFocusField,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormatter = DateFormat('dd.MM.yyyy');
    final currencyFormatter = NumberFormat.currency(
      locale: 'de_DE',
      symbol: '€',
    );

    // Use the cached family provider for single rechnung lookup
    final rechnungAsync = ref.watch(rechnungWithDetailsProvider(rechnungId));

    // Form controllers - initialize with empty/default values
    final ctrlStatus = useTextEditingController();
    final ctrlRechnungsnummer = useTextEditingController();
    final ctrlKundeName = useTextEditingController();
    final ctrlBemerkungTitel = useTextEditingController();
    final ctrlBemerkungText = useTextEditingController();

    // State values for dates
    final selectedStatus = useState<String>('offen');
    final originalStatus = useRef<String>('offen');
    final bezahltAm = useState<DateTime?>(null);
    final rechnungsDatum = useState<DateTime>(DateTime.now());
    final faelligkeitDatum = useState<DateTime>(
      DateTime.now().add(const Duration(days: 14)),
    );

    // Focus nodes
    final fnStatus = useFocusNode();

    // Saving state
    final isSaving = useState(false);

    // Track if data has been initialized
    final isInitialized = useRef<bool>(false);

    // Initialize form data when it loads
    useEffect(() {
      if (rechnungAsync.hasValue &&
          rechnungAsync.value != null &&
          !isInitialized.value) {
        final data = rechnungAsync.value!;
        final r = data.rechnung;

        // Set controller values
        ctrlRechnungsnummer.text = r.rechnungsnummer;
        ctrlKundeName.text = data.kundeName;
        ctrlStatus.text = r.status;

        // Set state values
        selectedStatus.value = r.status;
        originalStatus.value = r.status;
        bezahltAm.value = r.bezahltAm;
        rechnungsDatum.value = r.datum;
        faelligkeitDatum.value = r.faelligAm;

        // Initialize bemerkung if exists
        if (data.bemerkung != null) {
          ctrlBemerkungTitel.text = data.bemerkung!.titel;
          ctrlBemerkungText.text = data.bemerkung!.textValue ?? '';
        }

        isInitialized.value = true;
      }
      return null;
    }, [rechnungAsync.value]);

    // Keep status controller in sync
    useEffect(() {
      ctrlStatus.text = selectedStatus.value;
      return null;
    }, [selectedStatus.value]);

    // Auto-focus based on initialFocusField
    useEffect(() {
      if (isInitialized.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          switch (initialFocusField) {
            case 'status':
              fnStatus.requestFocus();
            default:
              // No default focus - dialog opens without focus
              break;
          }
        });
      }
      return null;
    }, [isInitialized.value]);

    /// Handles status change with automatic date handling
    void handleStatusChange(String newStatus) {
      selectedStatus.value = newStatus;
      ctrlStatus.text = newStatus;

      // Auto-set bezahlt_am when status changes to 'bezahlt'
      if (newStatus == 'bezahlt' && bezahltAm.value == null) {
        bezahltAm.value = DateTime.now();
      }
      // Clear bezahlt_am when status changes away from 'bezahlt'
      if (newStatus != 'bezahlt') {
        bezahltAm.value = null;
      }
    }

    /// Saves the rechnung with all changes
    Future<void> saveRechnung() async {
      isSaving.value = true;
      try {
        final repo = ref.read(rechnungenRepositoryProvider);
        final data = rechnungAsync.value;

        if (data == null) {
          throw Exception('Rechnung nicht gefunden');
        }

        // Determine bezahltAm based on status
        final newBezahltAm = selectedStatus.value == 'bezahlt'
            ? (bezahltAm.value ?? DateTime.now())
            : null;

        // Update the rechnung
        await repo.updateRechnungFull(
          id: rechnungId,
          status: selectedStatus.value,
          bezahltAm: newBezahltAm,
          bemerkungId: data.bemerkung?.id,
          bemerkungTitel: ctrlBemerkungTitel.text.trim(),
          bemerkungText: ctrlBemerkungText.text.trim(),
        );

        // Invalidate provider to refresh data
        ref.invalidate(rechnungWithDetailsProvider(rechnungId));
        ref.invalidate(rechnungenListProvider);

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rechnung erfolgreich gespeichert')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
        }
      } finally {
        isSaving.value = false;
      }
    }

    /// Deletes the rechnung
    Future<void> deleteRechnung() async {
      try {
        final repo = ref.read(rechnungenRepositoryProvider);
        await repo.deleteRechnung(rechnungId);

        // Invalidate providers
        ref.invalidate(rechnungenListProvider);

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rechnung erfolgreich gelöscht')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler beim Löschen: $e')));
        }
      }
    }

    // Loading state
    if (rechnungAsync.isLoading || !isInitialized.value) {
      return const AlertDialog(
        content: SizedBox(
          width: 100,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Error state
    if (rechnungAsync.hasError) {
      return AlertDialog(
        title: const Text('Fehler'),
        content: Text('Fehler beim Laden der Rechnung: ${rechnungAsync.error}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      );
    }

    final data = rechnungAsync.value;
    if (data == null) {
      return const AlertDialog(content: Text('Rechnung nicht gefunden.'));
    }

    final rechnung = data.rechnung;
    final positionen = data.positionen;

    return AppEditDialogScaffold(
      title: 'Rechnung bearbeiten',
      isSaving: isSaving.value,
      onSave: saveRechnung,
      onDelete: deleteRechnung,
      deleteEntityLabel: 'Rechnung',
      exportConfig: ExportConfig(
        item: data,
        entityType: 'rechnung',
        title: 'Rechnung ${ctrlRechnungsnummer.text}',
      ),
      contentWidth: 700,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Rechnung ───────────────────────────────────────────────────
          const AppSectionHeader('Rechnung'),
          const Gap(8),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: ctrlRechnungsnummer,
                  label: 'Rechnungs-Nr.',
                  readOnly: true,
                ),
              ),
              const Gap(16),
              Expanded(
                child: _buildStatusDropdown(
                  ctrlStatus,
                  fnStatus,
                  selectedStatus,
                  handleStatusChange,
                ),
              ),
            ],
          ),
          const Gap(16),

          // ── Kunde ──────────────────────────────────────────────────────
          const AppSectionHeader('Kunde'),
          const Gap(8),
          AppTextField(
            controller: ctrlKundeName,
            label: 'Kunde',
            readOnly: true,
          ),
          const Gap(16),

          // ── Daten ─────────────────────────────────────────────────────
          const AppSectionHeader('Daten'),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: TextEditingController(
                    text: dateFormatter.format(rechnungsDatum.value),
                  ),
                  label: 'Rechnungsdatum',
                  readOnly: true,
                ),
              ),
              const Gap(16),
              Expanded(
                child: AppTextField(
                  controller: TextEditingController(
                    text: dateFormatter.format(faelligkeitDatum.value),
                  ),
                  label: 'Fällig am',
                  readOnly: true,
                ),
              ),
            ],
          ),
          const Gap(16),

          // Bezahlt am (only when status is 'bezahlt')
          if (selectedStatus.value == 'bezahlt') ...[
            AppDatePickerField(
              value: bezahltAm.value,
              onChanged: (date) => bezahltAm.value = date,
              label: 'Bezahlt am',
            ),
            const Gap(16),
          ],

          // ── Positionen ─────────────────────────────────────────────────
          const AppSectionHeader('Positionen'),
          const Gap(8),
          _buildPositionenList(positionen, currencyFormatter),
          const Gap(16),

          // ── Summen ─────────────────────────────────────────────────────
          const AppSectionHeader('Summen'),
          const Gap(8),
          _buildSummaryRow(
            'Netto:',
            currencyFormatter.format(rechnung.betragNetto),
          ),
          _buildSummaryRow(
            'MwSt:',
            currencyFormatter.format(rechnung.betragMwst),
          ),
          _buildSummaryRow(
            'Brutto:',
            currencyFormatter.format(rechnung.betragBrutto),
            isBold: true,
          ),
          const Gap(24),

          // ── Bemerkung ──────────────────────────────────────────────────
          const AppSectionHeader('Bemerkung'),
          const Gap(8),
          AppTextField(controller: ctrlBemerkungTitel, label: 'Titel'),
          const Gap(8),
          AppTextField(
            controller: ctrlBemerkungText,
            label: 'Text',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  /// Builds the status dropdown with colored background.
  Widget _buildStatusDropdown(
    TextEditingController controller,
    FocusNode focusNode,
    ValueNotifier<String> selectedStatus,
    void Function(String) onStatusChanged,
  ) {
    return HookBuilder(
      builder: (context) {
        final bgColor = rechnungStatusColor(selectedStatus.value);

        // Create a wrapper controller to detect changes
        final wrapperController = useTextEditingController(
          text: controller.text,
        );

        useEffect(() {
          void listener() {
            if (wrapperController.text != selectedStatus.value) {
              onStatusChanged(wrapperController.text);
            }
          }

          wrapperController.addListener(listener);
          return () => wrapperController.removeListener(listener);
        }, []);

        // Sync with external controller
        useEffect(() {
          if (wrapperController.text != controller.text) {
            wrapperController.text = controller.text;
          }
          return null;
        }, [controller.text]);

        return Container(
          decoration: BoxDecoration(
            color: bgColor.withAlpha((255 * 0.3).round()),
            borderRadius: BorderRadius.circular(4),
          ),
          child: AppDropdownField<String>(
            controller: wrapperController,
            label: 'Status',
            focusNode: focusNode,
            options: kRechnungStatusValues,
            getLabel: (v) => v == 'offen'
                ? 'Offen'
                : v == 'bezahlt'
                ? 'Bezahlt'
                : 'Storniert',
          ),
        );
      },
    );
  }

  /// Builds the positions list widget.
  Widget _buildPositionenList(
    List<RechnungPosition> positionen,
    NumberFormat currencyFormatter,
  ) {
    if (positionen.isEmpty) {
      return const Text('Keine Positionen vorhanden.');
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: positionen.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final pos = positionen[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '${pos.positionNr}.',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(pos.bezeichnung, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: Text(
                    '${pos.menge.toStringAsFixed(2)} x',
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    currencyFormatter.format(pos.einzelpreisBrutto),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    currencyFormatter.format(pos.gesamtBrutto),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds a summary row for totals.
  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Gap(16),
          SizedBox(
            width: 120,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
