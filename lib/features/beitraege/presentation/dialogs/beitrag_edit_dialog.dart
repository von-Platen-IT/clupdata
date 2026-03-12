import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../../common_widgets/app_section_header.dart';
import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../common_widgets/forms/app_dropdown_field.dart';
import '../../../../common_widgets/forms/app_date_picker_field.dart';
import '../../../../core/database/database.dart';
import '../../providers/beitraege_repository.dart';
import '../../utils/beitrag_status_colors.dart';

/// Valid status values for a [Beitrag].
const kBeitragStatusValues = [
  'kontiert',
  'offen',
  'bezahlt',
  'angemahnt',
  'storniert',
  'inkasso',
];

/// Modal dialog for creating and editing a [Beitrag] record.
class BeitragEditDialog extends HookConsumerWidget {
  /// ID of the existing [Beitrag] to edit, or `null` for a new one.
  final int? beitragId;

  /// The column field that was double-clicked; used to set initial focus.
  final String? initialFocusField;

  const BeitragEditDialog({super.key, this.beitragId, this.initialFocusField});

  /// Static helper to open the dialog.
  static Future<void> show(
    BuildContext context, {
    int? beitragId,
    String? initialFocusField,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BeitragEditDialog(
        beitragId: beitragId,
        initialFocusField: initialFocusField,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beitraegeAsync = ref.watch(beitraegeListProvider);
    final dateFormatter = DateFormat('dd.MM.yyyy');

    // Find the existing record
    final rowData = beitraegeAsync.value ?? [];
    final existing = beitragId != null
        ? rowData.where((r) => r.beitrag.id == beitragId).firstOrNull
        : null;

    final isLoadingData = beitragId != null && beitraegeAsync.isLoading;

    // ── Form controllers ───────────────────────────────────────────────────
    final ctrlRechnungsnummer = useTextEditingController();
    final ctrlStatus = useTextEditingController();
    final ctrlKontiertAm = useState<DateTime>(DateTime.now());
    final ctrlStatusDatum = useState<DateTime>(DateTime.now());
    final ctrlStatusBemerkung = useTextEditingController();
    final ctrlBemerkungTitel = useTextEditingController();
    final ctrlBemerkungText = useTextEditingController();

    // ── Status History Stream ──────────────────────────────────────────────
    final statusHistoryStream = useMemoized(
      () => beitragId != null
          ? ref.read(beitraegeRepositoryProvider).watchStatusVerlauf(beitragId!)
          : Stream<List<BeitragStatusVerlaufData>>.value([]),
      [beitragId],
    );
    final statusHistoryAsync = useStream(statusHistoryStream);

    // ── Focus nodes ────────────────────────────────────────────────────────
    final fnRechnungsnummer = useFocusNode();
    final fnStatus = useFocusNode();

    // ── Data initialisation ────────────────────────────────────────────────
    useEffect(() {
      if (existing != null) {
        final b = existing.beitrag;
        ctrlRechnungsnummer.text = b.rechnungsnummer;
        ctrlStatus.text = b.status;
        ctrlKontiertAm.value = b.kontiertAm;
        ctrlStatusDatum.value = b.statusDatum;
      } else {
        // New record defaults
        ctrlStatus.text = 'kontiert';
        ctrlRechnungsnummer.text = 'RE-${DateTime.now().year}-';
      }
      return null;
    }, [existing]);

    // Auto focus
    useEffect(() {
      if (!isLoadingData) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          switch (initialFocusField) {
            case 'status':
              fnStatus.requestFocus();
            default:
              fnRechnungsnummer.requestFocus();
          }
        });
      }
      return null;
    }, [isLoadingData]);

    final isSaving = useState(false);
    final originalStatus = useRef<String?>(existing?.beitrag.status);

    // ── Save ───────────────────────────────────────────────────────────────
    Future<void> saveBeitrag() async {
      if (ctrlRechnungsnummer.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rechnungsnummer ist ein Pflichtfeld.')),
        );
        return;
      }

      isSaving.value = true;
      try {
        final repo = ref.read(beitraegeRepositoryProvider);
        final now = DateTime.now();
        // Update statusDatum if status has changed
        final statusChanged = ctrlStatus.text != originalStatus.value;
        final statusDatum = statusChanged ? now : ctrlStatusDatum.value;

        // Validate status bemerkung if status changed
        if (statusChanged && ctrlStatusBemerkung.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bei Statusänderung ist eine Bemerkung erforderlich.',
              ),
            ),
          );
          isSaving.value = false;
          return;
        }

        // Save bemerkung if provided
        int? bemerkungId = existing?.beitrag.bemerkungId;
        if (ctrlBemerkungTitel.text.isNotEmpty ||
            ctrlBemerkungText.text.isNotEmpty) {
          bemerkungId = await repo.saveBemerkung(
            bemerkungId,
            ctrlBemerkungTitel.text,
            ctrlBemerkungText.text,
          );
        }

        if (beitragId != null && existing != null) {
          // Update
          await repo.updateBeitrag(
            BeitraegeCompanion(
              id: drift.Value(beitragId!),
              rechnungsnummer: drift.Value(ctrlRechnungsnummer.text.trim()),
              status: drift.Value(ctrlStatus.text),
              kontiertAm: drift.Value(ctrlKontiertAm.value),
              statusDatum: drift.Value(statusDatum),
              bemerkungId: drift.Value(bemerkungId),
            ),
            statusBemerkung: statusChanged
                ? ctrlStatusBemerkung.text.trim()
                : null,
          );
        }
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erfolgreich gespeichert')),
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

    if (isLoadingData) {
      return const AlertDialog(
        content: SizedBox(
          width: 100,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AppEditDialogScaffold(
      title: beitragId == null ? 'Neuer Beitrag' : 'Beitrag bearbeiten',
      isSaving: isSaving.value,
      onSave: saveBeitrag,
      contentWidth: 700,
      onDelete: beitragId == null
          ? null
          : () async {
              await ref
                  .read(beitraegeRepositoryProvider)
                  .deleteBeitrag(beitragId!);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Beitrag erfolgreich gelöscht')),
                );
              }
            },
      deleteEntityLabel: 'Beitrag',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Beitrag / Rechnung ─────────────────────────────────────────
          const AppSectionHeader('Beitrag / Rechnung'),
          const Gap(8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: ctrlRechnungsnummer,
                  label: 'Rechnungs-Nr.',
                  focusNode: fnRechnungsnummer,
                  required: true,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextField(
                  controller: TextEditingController(
                    text: existing?.mitgliedName ?? '—',
                  ),
                  label: 'Mitglied',
                  readOnly: true,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextField(
                  controller: TextEditingController(
                    text: existing?.leistungName ?? '—',
                  ),
                  label: 'Leistung',
                  readOnly: true,
                ),
              ),
            ],
          ),
          const Gap(24),

          // ── Status & Daten ─────────────────────────────────────────────
          const AppSectionHeader('Status & Daten'),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: _buildStatusDropdown(
                  ctrlStatus,
                  fnStatus,
                  originalStatus.value,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppDatePickerField(
                  label: 'Kontiert am',
                  value: ctrlKontiertAm.value,
                  onChanged: (d) =>
                      ctrlKontiertAm.value = d ?? ctrlKontiertAm.value,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextField(
                  controller: TextEditingController(
                    text: dateFormatter.format(ctrlStatusDatum.value),
                  ),
                  label: 'Statusdatum',
                  readOnly: true,
                ),
              ),
            ],
          ),
          // Status change reason field (only shown when status changes)
          if (ctrlStatus.text != originalStatus.value) ...[
            const Gap(8),
            AppTextField(
              controller: ctrlStatusBemerkung,
              label: 'Grund der Statusänderung',
              maxLines: 2,
              required: true,
            ),
          ],
          const Gap(24),

          // ── Status-Historie ────────────────────────────────────────────
          if (beitragId != null) ...[
            const AppSectionHeader('Status-Historie'),
            const Gap(8),
            _buildStatusHistoryList(statusHistoryAsync, dateFormatter),
            const Gap(24),
          ],

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

  /// Builds the status dropdown with colored background for the selected value.
  Widget _buildStatusDropdown(
    TextEditingController controller,
    FocusNode focusNode,
    String? originalStatus,
  ) {
    return HookBuilder(
      builder: (context) {
        final bgColor = beitragStatusColor(controller.text);

        return Container(
          decoration: BoxDecoration(
            color: bgColor.withAlpha((255 * 0.3).round()),
            borderRadius: BorderRadius.circular(4),
          ),
          child: AppDropdownField<String>(
            controller: controller,
            label: 'Status',
            focusNode: focusNode,
            options: kBeitragStatusValues,
            getLabel: (v) => v,
          ),
        );
      },
    );
  }

  /// Builds the status history list widget.
  Widget _buildStatusHistoryList(
    AsyncSnapshot<List<BeitragStatusVerlaufData>> snapshot,
    DateFormat dateFormatter,
  ) {
    if (snapshot.hasError) {
      return Text('Fehler beim Laden der Historie: ${snapshot.error}');
    }
    if (!snapshot.hasData) {
      return const Center(
        child: SizedBox(
          height: 40,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final history = snapshot.data!;
    if (history.isEmpty) {
      return const Text('Keine Status-Historie vorhanden.');
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: history.length,
        itemBuilder: (context, index) {
          final entry = history[index];
          final bgColor = beitragStatusColor(entry.status);
          final textColor = beitragStatusTextColor(entry.status);

          return Container(
            decoration: BoxDecoration(
              color: bgColor.withAlpha((255 * 0.3).round()),
              border: Border(
                bottom: index < history.length - 1
                    ? BorderSide(color: Colors.grey.shade200)
                    : BorderSide.none,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    entry.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.bemerkung,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(2),
                      Text(
                        dateFormatter.format(entry.geaendertAm),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
