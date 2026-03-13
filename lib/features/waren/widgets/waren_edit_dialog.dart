import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../common_widgets/app_section_header.dart';
import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../common_widgets/forms/app_dropdown_field.dart';
import '../data/waren_repository.dart';
import '../presentation/providers/waren_list_provider.dart';

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';

/// Modal dialog for creating and editing a [Ware] record.
/// Triggered by double-clicking a row in [WarenDataGrid] or via the "Neu" button.
class WarenEditDialog extends HookConsumerWidget {
  /// ID of the existing [Ware] to edit, or `null` when creating a new one.
  final int? wareId;

  /// The field name of the cell that was double-clicked, used to set
  /// initial keyboard focus on the corresponding input widget.
  final String? initialFocusField;

  const WarenEditDialog({super.key, this.wareId, this.initialFocusField});

  /// Opens the dialog. Passes [wareId] for edit mode or omits it for create mode.
  static Future<void> show(
    BuildContext context, {
    int? wareId,
    String? initialFocusField,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          WarenEditDialog(wareId: wareId, initialFocusField: initialFocusField),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Data Loading ───────────────────────────────────────────────────────
    final detailsAsync = ref.watch(watchWarenDetailsProvider);
    final detailsList = detailsAsync.value ?? [];
    final details = wareId != null
        ? detailsList.where((d) => d.ware.id == wareId).firstOrNull
        : null;

    final settingsAsync = ref.watch(stammdatenSettingsMapForWarenProvider);
    final mwstRate = useMemoized(() {
      final settings = settingsAsync.value ?? {};
      final mwstKey = settings['mwst_aktiv_schluessel'] ?? 'mwst_standard';
      return double.tryParse(settings[mwstKey] ?? '19') ?? 19.0;
    }, [settingsAsync.value]);

    final mwstMultiplier = 1 + (mwstRate / 100);
    final isLoadingConfig = wareId != null && detailsAsync.isLoading;

    // ── Form Controllers ───────────────────────────────────────────────────
    // Allgemein
    final ctrlBezeichnung = useTextEditingController();
    final ctrlKategorie = useTextEditingController();
    final ctrlBeschreibung = useTextEditingController();
    final ctrlAktiv = useState<bool>(true);

    // Eigenschaften
    final ctrlGroesse = useTextEditingController();
    final ctrlFarbe = useTextEditingController();
    final ctrlGeschlecht = useTextEditingController();
    final ctrlMaterial = useTextEditingController();
    final ctrlGewichtKg = useTextEditingController();
    final ctrlEinheit = useTextEditingController();

    // Preise & Bestand
    final ctrlEinkaufspreis = useTextEditingController();
    final ctrlBruttopreis = useTextEditingController();
    final ctrlNettopreis = useTextEditingController();
    final ctrlBestand = useTextEditingController();
    final ctrlMindestbestand = useTextEditingController();

    // Logistik
    final ctrlLieferant = useTextEditingController();
    final ctrlHersteller = useTextEditingController();
    final ctrlHerstellerArtikelnr = useTextEditingController();

    // Bemerkung
    final ctrlBemerkungTitel = useTextEditingController();
    final ctrlBemerkungText = useTextEditingController();

    // ── Focus Nodes ────────────────────────────────────────────────────────
    final fnBezeichnung = useFocusNode();
    final fnKategorie = useFocusNode();
    final fnBeschreibung = useFocusNode();
    final fnGroesse = useFocusNode();
    final fnFarbe = useFocusNode();
    final fnGeschlecht = useFocusNode();
    final fnMaterial = useFocusNode();
    final fnGewichtKg = useFocusNode();
    final fnEinheit = useFocusNode();
    final fnEinkaufspreis = useFocusNode();
    final fnBruttopreis = useFocusNode();
    final fnBestand = useFocusNode();
    final fnMindestbestand = useFocusNode();
    final fnLieferant = useFocusNode();
    final fnHersteller = useFocusNode();
    final fnHerstellerArtikelnr = useFocusNode();

    // ── Data Initialization ────────────────────────────────────────────────
    useEffect(() {
      if (details != null) {
        final w = details.ware;
        ctrlBezeichnung.text = w.bezeichnung;
        ctrlKategorie.text = w.kategorie ?? '';
        ctrlBeschreibung.text = w.beschreibung ?? '';
        ctrlAktiv.value = w.aktiv;

        ctrlGroesse.text = w.groesse ?? '';
        ctrlFarbe.text = w.farbe ?? '';
        ctrlGeschlecht.text = w.geschlecht ?? '';
        ctrlMaterial.text = w.material ?? '';
        ctrlGewichtKg.text = w.gewichtKg?.toString() ?? '';
        ctrlEinheit.text = w.einheit ?? '';

        ctrlEinkaufspreis.text = w.einkaufspreis?.toStringAsFixed(2) ?? '';
        ctrlBruttopreis.text = w.bruttopreis.toStringAsFixed(2);
        ctrlNettopreis.text = (w.bruttopreis / mwstMultiplier).toStringAsFixed(
          2,
        );
        ctrlBestand.text = w.bestand.toString();
        ctrlMindestbestand.text = w.mindestbestand.toString();

        ctrlLieferant.text = w.lieferant ?? '';
        ctrlHersteller.text = w.hersteller ?? '';
        ctrlHerstellerArtikelnr.text = w.herstellerArtikelnr ?? '';

        final b = details.bemerkung;
        ctrlBemerkungTitel.text = b?.titel ?? '';
        ctrlBemerkungText.text = b?.textValue ?? '';
      } else {
        // Defaults for new record
        ctrlBestand.text = '0';
        ctrlMindestbestand.text = '0';
      }
      return null;
    }, [details, mwstMultiplier]);

    // ── Brutto ↔ Netto live calculation ────────────────────────────────────
    // Guard flag prevents infinite listener loops between the two controllers
    final isUpdatingPrice = useRef(false);

    useEffect(() {
      void updateNetto() {
        if (isUpdatingPrice.value) return;
        final bruttoVal = double.tryParse(
          ctrlBruttopreis.text.replaceAll(',', '.'),
        );
        isUpdatingPrice.value = true;
        ctrlNettopreis.text = bruttoVal != null
            ? (bruttoVal / mwstMultiplier).toStringAsFixed(2)
            : '';
        isUpdatingPrice.value = false;
      }

      void updateBrutto() {
        if (isUpdatingPrice.value) return;
        final nettoVal = double.tryParse(
          ctrlNettopreis.text.replaceAll(',', '.'),
        );
        isUpdatingPrice.value = true;
        ctrlBruttopreis.text = nettoVal != null
            ? (nettoVal * mwstMultiplier).toStringAsFixed(2)
            : '';
        isUpdatingPrice.value = false;
      }

      ctrlBruttopreis.addListener(updateNetto);
      ctrlNettopreis.addListener(updateBrutto);
      return () {
        ctrlBruttopreis.removeListener(updateNetto);
        ctrlNettopreis.removeListener(updateBrutto);
      };
    }, [mwstMultiplier]);

    // ── Auto Focus (contextual editing from grid double-click) ─────────────
    useEffect(() {
      if (!isLoadingConfig) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          switch (initialFocusField) {
            case 'bezeichnung':
              fnBezeichnung.requestFocus();
            case 'kategorie':
              fnKategorie.requestFocus();
            case 'bestand':
              fnBestand.requestFocus();
            case 'bruttopreis':
              fnBruttopreis.requestFocus();
            default:
              fnBezeichnung.requestFocus(); // sensible default
          }
        });
      }
      return null;
    }, [isLoadingConfig]);

    final isSaving = useState(false);

    // ── Save Action ────────────────────────────────────────────────────────
    Future<void> saveWare() async {
      if (ctrlBezeichnung.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bezeichnung ist ein Pflichtfeld.')),
        );
        return;
      }
      final bruttoVal = double.tryParse(
        ctrlBruttopreis.text.replaceAll(',', '.'),
      );
      if (bruttoVal == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ungültiger Bruttopreis.')),
        );
        return;
      }

      isSaving.value = true;
      try {
        await ref
            .read(warenRepositoryProvider)
            .saveWareFull(
              wareId: wareId,
              bezeichnung: ctrlBezeichnung.text.trim(),
              beschreibung: ctrlBeschreibung.text,
              kategorie: ctrlKategorie.text,
              groesse: ctrlGroesse.text,
              farbe: ctrlFarbe.text,
              geschlecht: ctrlGeschlecht.text,
              material: ctrlMaterial.text,
              einkaufspreis: double.tryParse(
                ctrlEinkaufspreis.text.replaceAll(',', '.'),
              ),
              bruttopreis: bruttoVal,
              bestand: int.tryParse(ctrlBestand.text) ?? 0,
              mindestbestand: int.tryParse(ctrlMindestbestand.text) ?? 0,
              lieferant: ctrlLieferant.text,
              hersteller: ctrlHersteller.text,
              herstellerArtikelnr: ctrlHerstellerArtikelnr.text,
              gewichtKg: double.tryParse(
                ctrlGewichtKg.text.replaceAll(',', '.'),
              ),
              einheit: ctrlEinheit.text,
              aktiv: ctrlAktiv.value,
              existingBemerkungId: details?.bemerkung?.id,
              bemerkungTitel: ctrlBemerkungTitel.text,
              bemerkungText: ctrlBemerkungText.text,
            );
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

    // ── Loading Placeholder ────────────────────────────────────────────────
    if (isLoadingConfig) {
      return const AlertDialog(
        content: SizedBox(
          width: 100,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AppEditDialogScaffold(
      title: wareId == null ? 'Neue Ware' : 'Ware bearbeiten',
      isSaving: isSaving.value,
      onSave: saveWare,
      contentWidth: 800,
      deleteEntityLabel: 'Ware',
      onDelete: wareId == null
          ? null
          : () async {
              await ref.read(warenRepositoryProvider).deleteWare(wareId!);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ware erfolgreich gelöscht')),
                );
              }
            },
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Allgemein ──────────────────────────────────────────
          const AppSectionHeader('Allgemein'),
          const Gap(8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: AppTextField(
                  controller: ctrlBezeichnung,
                  label: 'Bezeichnung',
                  focusNode: fnBezeichnung,
                  required: true,
                ),
              ),
              const Gap(8),
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: ctrlKategorie,
                  label: 'Kategorie',
                  focusNode: fnKategorie,
                ),
              ),
            ],
          ),
          const Gap(8),
          AppTextField(
            controller: ctrlBeschreibung,
            label: 'Beschreibung',
            focusNode: fnBeschreibung,
            maxLines: 2,
          ),
          const Gap(8),
          Row(
            children: [
              Checkbox(
                value: ctrlAktiv.value,
                onChanged: (v) => ctrlAktiv.value = v ?? false,
              ),
              const Text('Aktiv (für Verkauf verfügbar)'),
            ],
          ),
          const Gap(24),

          // ── Eigenschaften ──────────────────────────────────────
          const AppSectionHeader('Eigenschaften'),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: ctrlGroesse,
                  label: 'Größe',
                  focusNode: fnGroesse,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextField(
                  controller: ctrlFarbe,
                  label: 'Farbe',
                  focusNode: fnFarbe,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppDropdownField<String>(
                  controller: ctrlGeschlecht,
                  label: 'Geschlecht',
                  focusNode: fnGeschlecht,
                  options: const ['Unisex', 'Herren', 'Damen', 'Kinder'],
                  getLabel: (v) => v,
                ),
              ),
            ],
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: ctrlMaterial,
                  label: 'Material',
                  focusNode: fnMaterial,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextField(
                  controller: ctrlGewichtKg,
                  label: 'Gewicht (kg)',
                  focusNode: fnGewichtKg,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextField(
                  controller: ctrlEinheit,
                  label: 'Einheit',
                  focusNode: fnEinheit,
                ),
              ),
            ],
          ),
          const Gap(24),

          // ── Preise & Bestand ───────────────────────────────────
          const AppSectionHeader('Preise & Bestand'),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: ctrlEinkaufspreis,
                  label: 'Einkaufspreis (€)',
                  focusNode: fnEinkaufspreis,
                  keyboardType: TextInputType.number,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextField(
                  controller: ctrlBruttopreis,
                  label: 'VK Brutto (€)',
                  focusNode: fnBruttopreis,
                  keyboardType: TextInputType.number,
                ),
              ),
              const Gap(8),
              // Netto is computed — read-only, no focusNode needed
              Expanded(
                child: AppTextField(
                  controller: ctrlNettopreis,
                  label: 'VK Netto (€)',
                  readOnly: true,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: ctrlBestand,
                  label: 'Bestand',
                  focusNode: fnBestand,
                  keyboardType: TextInputType.number,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextField(
                  controller: ctrlMindestbestand,
                  label: 'Mindestbestand',
                  focusNode: fnMindestbestand,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const Gap(24),

          // ── Logistik & Hersteller ──────────────────────────────
          const AppSectionHeader('Logistik & Hersteller'),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: ctrlLieferant,
                  label: 'Lieferant',
                  focusNode: fnLieferant,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextField(
                  controller: ctrlHersteller,
                  label: 'Hersteller',
                  focusNode: fnHersteller,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextField(
                  controller: ctrlHerstellerArtikelnr,
                  label: 'Artikelnr. HF',
                  focusNode: fnHerstellerArtikelnr,
                ),
              ),
            ],
          ),
          const Gap(24),

          // ── Bemerkung ──────────────────────────────────────────
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
}
