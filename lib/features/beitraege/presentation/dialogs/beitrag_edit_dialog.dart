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
import '../../../../core/data/bemerkung_repository.dart';
import '../../../../core/database/database.dart';
import '../../../../core/utils/color_extensions.dart';
import '../../domain/models/beitrag_status.dart';
import '../../data/beitraege_repository.dart';
import '../../presentation/providers/beitraege_list_provider.dart';
import '../widgets/beitrag_status_history_grid.dart';
import '../../domain/models/beitrag_status_history_row_data.dart';
import '../../../export/domain/export_config.dart';

/// Returns true if the dialog can be saved.
/// - Rechnungsnummer must not be empty
/// - If status changed, statusBemerkung must not be empty
bool _canSave({
  required String rechnungsnummer,
  required String currentStatus,
  required String? originalStatus,
  required String statusBemerkung,
}) {
  if (rechnungsnummer.trim().isEmpty) return false;
  final statusChanged = currentStatus != originalStatus;
  if (statusChanged && statusBemerkung.trim().isEmpty) return false;
  return true;
}

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

    // Track if data has been initialized (to prevent overwriting user input on stream updates)
    final isInitialized = useRef<bool>(false);

    // ── Data initialisation ────────────────────────────────────────────────
    useEffect(() {
      // Only initialize once to prevent overwriting user input when stream updates
      if (isInitialized.value) return null;

      if (existing != null) {
        final b = existing.beitrag;
        ctrlRechnungsnummer.text = b.rechnungsnummer;
        ctrlStatus.text = b.status;
        ctrlKontiertAm.value = b.kontiertAm;
        ctrlStatusDatum.value = b.statusDatum;
        isInitialized.value = true;
      } else if (beitragId == null) {
        // New record defaults
        ctrlStatus.text = 'kontiert';
        ctrlRechnungsnummer.text = 'RE-${DateTime.now().year}-';
        isInitialized.value = true;
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
    // Track the status at the time of dialog open to detect changes
    // This is set once when the dialog opens and doesn't change during editing
    final originalStatus = useState<String?>(null);

    // Initialize originalStatus only once when data is first loaded
    useEffect(() {
      if (existing != null && originalStatus.value == null) {
        originalStatus.value = existing.beitrag.status;
      }
      return null;
    }, [existing?.beitrag.status]);

    // Track whether the form can be saved (reactive)
    final canSave = useState(false);

    // Recompute canSave whenever relevant fields change
    void updateCanSave() {
      canSave.value = _canSave(
        rechnungsnummer: ctrlRechnungsnummer.text,
        currentStatus: ctrlStatus.text,
        originalStatus: originalStatus.value,
        statusBemerkung: ctrlStatusBemerkung.text,
      );
    }

    // Listen to controller changes
    useEffect(() {
      void listener() => updateCanSave();
      ctrlRechnungsnummer.addListener(listener);
      ctrlStatus.addListener(listener);
      ctrlStatusBemerkung.addListener(listener);
      // Initial check
      updateCanSave();
      return () {
        ctrlRechnungsnummer.removeListener(listener);
        ctrlStatus.removeListener(listener);
        ctrlStatusBemerkung.removeListener(listener);
      };
    }, [originalStatus.value]);

    // ── Save ───────────────────────────────────────────────────────────────
    Future<void> saveBeitrag() async {
      if (!_canSave(
        rechnungsnummer: ctrlRechnungsnummer.text,
        currentStatus: ctrlStatus.text,
        originalStatus: originalStatus.value,
        statusBemerkung: ctrlStatusBemerkung.text,
      )) {
        if (ctrlRechnungsnummer.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rechnungsnummer ist ein Pflichtfeld.'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bei Statusänderung ist eine Bemerkung erforderlich.',
              ),
            ),
          );
        }
        return;
      }

      isSaving.value = true;
      try {
        final repo = ref.read(beitraegeRepositoryProvider);
        final now = DateTime.now();
        // Update statusDatum if status has changed
        final statusChanged = ctrlStatus.text != originalStatus.value;
        final statusDatum = statusChanged ? now : ctrlStatusDatum.value;

        // Save bemerkung if provided
        int? bemerkungId = existing?.beitrag.bemerkungId;
        if (ctrlBemerkungTitel.text.isNotEmpty ||
            ctrlBemerkungText.text.isNotEmpty) {
          final bemerkungRepo = ref.read(bemerkungRepositoryProvider);
          bemerkungId = await bemerkungRepo.saveBemerkung(
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
      isSaveEnabled: canSave.value,
      contentWidth: 700,
      exportConfig: beitragId == null
          ? null
          : ExportConfig(
              item: existing,
              entityType: 'beitrag',
              title: 'Beitrag ${ctrlRechnungsnummer.text}',
            ),
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
          // Status change reason field (always visible)
          const Gap(8),
          AppTextField(
            controller: ctrlStatusBemerkung,
            label: 'Grund der Statusänderung',
            maxLines: 2,
            required: originalStatus.value != null &&
                ctrlStatus.text != originalStatus.value,
          ),
          const Gap(24),

          // ── Status-Historie ────────────────────────────────────────────
          if (beitragId != null) ...[
            const AppSectionHeader('Status-Historie'),
            const Gap(8),
            _buildStatusHistoryGrid(statusHistoryAsync, dateFormatter),
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
        final status = BeitragStatus.fromString(controller.text);

        return Container(
          decoration: BoxDecoration(
            color: status.backgroundColor.withOpacityPercent(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: AppDropdownField<String>(
            controller: controller,
            label: 'Status',
            focusNode: focusNode,
            options: BeitragStatus.allStringValues,
            getLabel: (v) => BeitragStatus.fromString(v).label,
          ),
        );
      },
    );
  }

  /// Builds the status history grid widget using VpitDataGrid.
  Widget _buildStatusHistoryGrid(
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

    // Map VerlaufData to HistoryRowData - status comes from history entry
    final historyRows = snapshot.data!
        .map((verlauf) => BeitragStatusHistoryRowData.fromVerlauf(verlauf))
        .toList();

    return BeitragStatusHistoryGrid(
      history: historyRows,
      dateFormatter: dateFormatter,
    );
  }
}
