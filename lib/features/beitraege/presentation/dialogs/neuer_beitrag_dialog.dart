import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../../common_widgets/app_section_header.dart';
import '../../../../common_widgets/forms/app_date_picker_field.dart';
import '../../../../common_widgets/forms/app_entity_autocomplete.dart';
import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../core/database/database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../leistungen/data/leistungen_repository.dart';
import '../../../members/data/members_repository.dart';
import '../../domain/models/beitrag_status.dart';
import '../../providers/beitraege_repository.dart';
import '../widgets/status_badge.dart';

/// Dialog for creating a new Beitrag (invoice/contribution).
/// Features:
/// - Auto-generated invoice number (small, non-prominent)
/// - Member search by first or last name with autocomplete
/// - Service (Leistung) search with autocomplete
/// - Contribution amount from member (editable)
/// - Automatic status "kontiert"
class NeuerBeitragDialog extends HookConsumerWidget {
  const NeuerBeitragDialog({super.key});

  /// Static helper to open the dialog.
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NeuerBeitragDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormatter = DateFormat('dd.MM.yyyy');
    final db = ref.watch(appDatabaseProvider);

    // ── State ───────────────────────────────────────────────────────────────
    final isSaving = useState(false);
    final rechnungsnummer = useState<String>('');

    // Selected entities
    final selectedMember = useState<Mitglied?>(null);
    final selectedLeistung = useState<LeistungsDetail?>(null);

    // Controllers
    final memberSearchController = useTextEditingController();
    final leistungSearchController = useTextEditingController();
    final beitragController = useTextEditingController();
    final kontiertAm = useState<DateTime>(DateTime.now());

    // Search results
    final memberSearchResults = useState<List<Mitglied>>([]);
    final leistungSearchResults = useState<List<LeistungsDetail>>([]);

    // Loading states
    final isLoadingInvoiceNumber = useState(true);

    // ── Initialization ───────────────────────────────────────────────────────
    useEffect(() {
      // Generate invoice number on mount
      Future<void> init() async {
        final repo = ref.read(beitraegeRepositoryProvider);
        rechnungsnummer.value = await repo.generateRechnungsnummer();
        isLoadingInvoiceNumber.value = false;
      }

      init();
      return null;
    }, []);

    // ── Member Search ────────────────────────────────────────────────────────
    Future<void> searchMembers(String query) async {
      if (query.length < 2) {
        memberSearchResults.value = [];
        return;
      }
      final repo = ref.read(membersRepositoryProvider);
      final results = await repo.searchMembers(query);
      memberSearchResults.value = results;
    }

    Future<void> loadAllMembers() async {
      final repo = ref.read(membersRepositoryProvider);
      final results = await repo.getAllMembers();
      memberSearchResults.value = results;
    }

    // ── Leistung Search ──────────────────────────────────────────────────────
    Future<void> searchLeistungen(String query) async {
      if (query.length < 2) {
        leistungSearchResults.value = [];
        return;
      }
      final repo = ref.read(leistungenRepositoryProvider);
      final results = await repo.searchLeistungen(query);
      leistungSearchResults.value = results;
    }

    Future<void> loadAllLeistungen() async {
      final repo = ref.read(leistungenRepositoryProvider);
      final results = await repo.getAllLeistungenDetails();
      leistungSearchResults.value = results;
    }

    // ── Update Beitrag when member changes ───────────────────────────────────
    useEffect(() {
      final member = selectedMember.value;
      if (member != null && member.preisId != null) {
        // Load the member's price
        Future<void> loadPrice() async {
          final repo = ref.read(membersRepositoryProvider);
          final (_, preis) = await repo.getMemberWithPrice(member.id);
          if (preis != null) {
            beitragController.text = preis.bruttopreis.toStringAsFixed(2);
          }
        }

        loadPrice();
      }
      return null;
    }, [selectedMember.value]);

    // ── Save ─────────────────────────────────────────────────────────────────
    Future<void> saveBeitrag() async {
      // Validation
      if (selectedMember.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte wählen Sie ein Mitglied aus.')),
        );
        return;
      }
      if (selectedLeistung.value == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte wählen Sie eine Leistung aus.')),
        );
        return;
      }
      if (beitragController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte geben Sie einen Beitrag ein.')),
        );
        return;
      }

      final beitragValue = double.tryParse(
        beitragController.text.replaceAll(',', '.'),
      );
      if (beitragValue == null || beitragValue <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte geben Sie einen gültigen Beitrag ein.'),
          ),
        );
        return;
      }

      isSaving.value = true;
      try {
        final repo = ref.read(beitraegeRepositoryProvider);

        // Create or get price entry
        final preisId = await db
            .into(db.preis)
            .insert(PreisCompanion.insert(bruttopreis: beitragValue));

        // Create the beitrag
        await repo.addBeitrag(
          BeitraegeCompanion.insert(
            mitgliedId: selectedMember.value!.id,
            leistungId: selectedLeistung.value!.leistung.id,
            preisId: drift.Value(preisId),
            rechnungsnummer: rechnungsnummer.value,
            status: 'kontiert',
            kontiertAm: kontiertAm.value,
            statusDatum: kontiertAm.value,
          ),
        );

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Beitrag erfolgreich erstellt')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler beim Erstellen: $e')));
        }
      } finally {
        isSaving.value = false;
      }
    }

    if (isLoadingInvoiceNumber.value) {
      return const AlertDialog(
        content: SizedBox(
          width: 100,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AppEditDialogScaffold(
      title: 'Neuer Beitrag',
      isSaving: isSaving.value,
      onSave: saveBeitrag,
      contentWidth: 600,
      onDelete: null,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Invoice Number (small, non-prominent) ──────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Rechnungs-Nr.: ${rechnungsnummer.value}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
          const Gap(16),

          // ── Member Selection ───────────────────────────────────────────────
          const AppSectionHeader('Mitglied'),
          const Gap(8),
          _buildMemberAutocomplete(
            context,
            memberSearchController,
            selectedMember,
            memberSearchResults,
            searchMembers,
            loadAllMembers,
          ),
          if (selectedMember.value != null) ...[
            const Gap(8),
            _buildSelectedMemberInfo(context, selectedMember.value!),
          ],
          const Gap(24),

          // ── Service (Leistung) Selection ───────────────────────────────────
          const AppSectionHeader('Leistung'),
          const Gap(8),
          _buildLeistungAutocomplete(
            context,
            leistungSearchController,
            selectedLeistung,
            leistungSearchResults,
            searchLeistungen,
            loadAllLeistungen,
          ),
          if (selectedLeistung.value != null) ...[
            const Gap(8),
            _buildSelectedLeistungInfo(context, selectedLeistung.value!),
          ],
          const Gap(24),

          // ── Contribution & Date ────────────────────────────────────────────
          const AppSectionHeader('Beitrag & Daten'),
          const Gap(8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: beitragController,
                  label: 'Beitrag (€)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const Gap(16),
              Expanded(
                flex: 2,
                child: AppDatePickerField(
                  label: 'Kontiert am',
                  value: kontiertAm.value,
                  onChanged: (d) => kontiertAm.value = d ?? kontiertAm.value,
                ),
              ),
              const Gap(16),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: BeitragStatus.kontiert.backgroundColor
                        .withOpacityPercent(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: BeitragStatus.kontiert.backgroundColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Gap(8),
                      Text(
                        BeitragStatus.kontiert.label,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the member autocomplete search field.
  Widget _buildMemberAutocomplete(
    BuildContext context,
    TextEditingController controller,
    ValueNotifier<Mitglied?> selectedMember,
    ValueNotifier<List<Mitglied>> searchResults,
    Future<void> Function(String) onSearch,
    Future<void> Function() loadAll,
  ) {
    return Autocomplete<Mitglied>(
      optionsBuilder: (textEditingValue) {
        // Show all results when text is exactly ' ' (triggered by search button)
        if (textEditingValue.text == ' ') {
          return searchResults.value;
        }
        if (textEditingValue.text.length < 2) {
          return const Iterable<Mitglied>.empty();
        }
        // Trigger search and return current results
        onSearch(textEditingValue.text);
        return searchResults.value;
      },
      displayStringForOption: (member) => '${member.vorname} ${member.name}',
      onSelected: (member) {
        selectedMember.value = member;
        controller.text = '${member.vorname} ${member.name}';
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            // Sync external controller with internal one
            if (controller.text != textEditingController.text) {
              textEditingController.text = controller.text;
            }

            return Stack(
              alignment: Alignment.centerRight,
              children: [
                TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Mitglied suchen (Vor- oder Nachname)',
                    hintText: 'Mindestens 2 Zeichen eingeben...',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: selectedMember.value != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              selectedMember.value = null;
                              controller.clear();
                              textEditingController.clear();
                            },
                          )
                        : const SizedBox(width: 40, height: 40),
                  ),
                  onChanged: (value) {
                    controller.text = value;
                    if (selectedMember.value != null) {
                      selectedMember.value = null;
                    }
                  },
                ),
                if (selectedMember.value == null)
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) async {
                        // Preload data on tap down
                        await loadAll();
                      },
                      onTapUp: (_) {
                        // Trigger the autocomplete on tap up while keeping focus
                        textEditingController.text = ' ';
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: const Icon(Icons.search, size: 20),
                      ),
                    ),
                  ),
              ],
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: Container(
              width: 400,
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final member = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text('${member.vorname} ${member.name}'),
                    subtitle: Text('${member.plz ?? ''} ${member.ort ?? ''}'),
                    onTap: () => onSelected(member),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the selected member info card.
  Widget _buildSelectedMemberInfo(BuildContext context, Mitglied member) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: Colors.blue.shade700),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${member.vorname} ${member.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (member.ort != null && member.ort!.isNotEmpty)
                  Text(
                    '${member.plz ?? ''} ${member.ort}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the leistung autocomplete search field.
  Widget _buildLeistungAutocomplete(
    BuildContext context,
    TextEditingController controller,
    ValueNotifier<LeistungsDetail?> selectedLeistung,
    ValueNotifier<List<LeistungsDetail>> searchResults,
    Future<void> Function(String) onSearch,
    Future<void> Function() loadAll,
  ) {
    return Autocomplete<LeistungsDetail>(
      optionsBuilder: (textEditingValue) {
        // Show all results when text is exactly ' ' (triggered by search button)
        if (textEditingValue.text == ' ') {
          return searchResults.value;
        }
        if (textEditingValue.text.length < 2) {
          return const Iterable<LeistungsDetail>.empty();
        }
        onSearch(textEditingValue.text);
        return searchResults.value;
      },
      displayStringForOption: (detail) => detail.leistung.name,
      onSelected: (detail) {
        selectedLeistung.value = detail;
        controller.text = detail.leistung.name;
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            if (controller.text != textEditingController.text) {
              textEditingController.text = controller.text;
            }

            return Stack(
              alignment: Alignment.centerRight,
              children: [
                TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Leistung suchen',
                    hintText: 'Mindestens 2 Zeichen eingeben...',
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: selectedLeistung.value != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              selectedLeistung.value = null;
                              controller.clear();
                              textEditingController.clear();
                            },
                          )
                        : const SizedBox(width: 40, height: 40),
                  ),
                  onChanged: (value) {
                    controller.text = value;
                    if (selectedLeistung.value != null) {
                      selectedLeistung.value = null;
                    }
                  },
                ),
                if (selectedLeistung.value == null)
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) async {
                        // Preload data on tap down
                        await loadAll();
                      },
                      onTapUp: (_) {
                        // Trigger the autocomplete on tap up while keeping focus
                        textEditingController.text = ' ';
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: const Icon(Icons.search, size: 20),
                      ),
                    ),
                  ),
              ],
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: Container(
              width: 400,
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final detail = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(detail.leistung.name),
                    subtitle: Text(
                      '${detail.leistung.laufzeit} - ${detail.preis.bruttopreis.toStringAsFixed(2)} €',
                    ),
                    onTap: () => onSelected(detail),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the selected leistung info card.
  Widget _buildSelectedLeistungInfo(
    BuildContext context,
    LeistungsDetail detail,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.fitness_center, color: Colors.green.shade700),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.leistung.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${detail.leistung.laufzeit} - Standard: ${detail.preis.bruttopreis.toStringAsFixed(2)} €',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
