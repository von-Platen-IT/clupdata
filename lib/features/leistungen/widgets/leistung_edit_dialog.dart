import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../common_widgets/forms/app_dropdown_field.dart';
import '../data/leistungen_repository.dart';
import '../domain/models/leistungs_detail.dart';
import '../presentation/providers/leistungen_list_provider.dart';
import '../domain/models/leistung_detail_export_provider.dart';
import '../../export/domain/export_config.dart';

class LeistungEditDialog extends HookConsumerWidget {
  final LeistungsDetail? details;
  final String? initialFocusField;

  const LeistungEditDialog({super.key, this.details, this.initialFocusField});

  static Future<void> show(
    BuildContext context, {
    LeistungsDetail? details,
    String? initialFocusField,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LeistungEditDialog(
        details: details,
        initialFocusField: initialFocusField,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Load Settings for MwSt
    final settingsAsync = ref.watch(stammdatenSettingsMapProvider);
    final mwstRate = useMemoized(() {
      final settings = settingsAsync.value ?? {};
      final mwstKey = settings['mwst_aktiv_schluessel'] ?? 'mwst_standard';
      return double.tryParse(settings[mwstKey] ?? '19') ?? 19.0;
    }, [settingsAsync.value]);

    final mwstMultiplier = 1 + (mwstRate / 100);

    // Controller Setup
    final ctrlName = useTextEditingController(
      text: details?.leistung.name ?? '',
    );
    final ctrlLaufzeit = useTextEditingController(
      text: details?.leistung.laufzeit ?? 'monatlich',
    );

    // We treat brutto as string for text input
    final initialBrutto = details?.preis.bruttopreis ?? 0.0;
    final initialNetto = initialBrutto / mwstMultiplier;

    final ctrlBrutto = useTextEditingController(
      text: initialBrutto > 0 ? initialBrutto.toStringAsFixed(2) : '',
    );
    final ctrlNetto = useTextEditingController(
      text: initialNetto > 0 ? initialNetto.toStringAsFixed(2) : '',
    );

    final isUpdatingPrice = useRef(false);

    useEffect(() {
      void updateNetto() {
        if (isUpdatingPrice.value) return;
        final bruttoVal = double.tryParse(ctrlBrutto.text.replaceAll(',', '.'));
        if (bruttoVal != null) {
          isUpdatingPrice.value = true;
          ctrlNetto.text = (bruttoVal / mwstMultiplier).toStringAsFixed(2);
          isUpdatingPrice.value = false;
        } else if (ctrlBrutto.text.isEmpty) {
          isUpdatingPrice.value = true;
          ctrlNetto.text = '';
          isUpdatingPrice.value = false;
        }
      }

      void updateBrutto() {
        if (isUpdatingPrice.value) return;
        final nettoVal = double.tryParse(ctrlNetto.text.replaceAll(',', '.'));
        if (nettoVal != null) {
          isUpdatingPrice.value = true;
          ctrlBrutto.text = (nettoVal * mwstMultiplier).toStringAsFixed(2);
          isUpdatingPrice.value = false;
        } else if (ctrlNetto.text.isEmpty) {
          isUpdatingPrice.value = true;
          ctrlBrutto.text = '';
          isUpdatingPrice.value = false;
        }
      }

      ctrlBrutto.addListener(updateNetto);
      ctrlNetto.addListener(updateBrutto);

      return () {
        ctrlBrutto.removeListener(updateNetto);
        ctrlNetto.removeListener(updateBrutto);
      };
    }, [mwstMultiplier]);

    final ctrlBemerkungTitel = useTextEditingController(
      text: details?.bemerkung?.titel ?? '',
    );
    final ctrlBemerkungText = useTextEditingController(
      text: details?.bemerkung?.textValue ?? '',
    );

    // Focus Node Setup
    final fnName = useFocusNode();
    final fnLaufzeit = useFocusNode();
    final fnBrutto = useFocusNode();

    // Auto Focus logic
    useEffect(() {
      if (initialFocusField != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          switch (initialFocusField) {
            case 'name':
              fnName.requestFocus();
              break;
            case 'laufzeit':
              fnLaufzeit.requestFocus();
              break;
            case 'bruttopreis':
              fnBrutto.requestFocus();
              break;
          }
        });
      }
      return null;
    }, [initialFocusField]);

    final isSaving = useState(false);

    Future<void> save() async {
      if (ctrlName.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name ist ein Pflichtfeld.')),
        );
        return;
      }

      final bruttoVal = double.tryParse(ctrlBrutto.text.replaceAll(',', '.'));
      if (bruttoVal == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ungültiger Bruttopreis.')),
        );
        return;
      }

      isSaving.value = true;
      try {
        final repo = ref.read(leistungenRepositoryProvider);

        await repo.saveLeistungFull(
          leistungId: details?.leistung.id,
          name: ctrlName.text,
          laufzeit: ctrlLaufzeit.text,
          existingPreisId: details?.preis.id,
          bruttopreis: bruttoVal,
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

    return AppEditDialogScaffold(
      title: details == null ? 'Neue Leistung' : 'Leistung bearbeiten',
      isSaving: isSaving.value,
      onSave: save,
      contentWidth: 600,
      deleteEntityLabel: 'Leistung',
      exportConfig: details == null
          ? null
          : ExportConfig(
              detailProvider: LeistungDetailExportProvider(
                leistung: details!.leistung,
                preis: details!.preis,
                bemerkung: details!.bemerkung,
              ),
              entityType: 'leistung',
              title: 'Leistung ${ctrlName.text}',
            ),
      onDelete: details?.leistung.id == null
          ? null
          : () async {
              await ref
                  .read(leistungenRepositoryProvider)
                  .deleteLeistung(details!.leistung.id);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Leistung erfolgreich gelöscht'),
                  ),
                );
              }
            },
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leistung',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(8),
          AppTextField(controller: ctrlName, label: 'Name', focusNode: fnName),
          const Gap(8),
          AppDropdownField<String>(
            controller: ctrlLaufzeit,
            label: 'Laufzeit',
            focusNode: fnLaufzeit,
            options: const [
              'einmalig',
              'monatlich',
              'quartalsweise',
              'jaehrlich',
            ],
            getLabel: (v) => v,
          ),
          const Gap(24),

          Text(
            'Preis',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: ctrlBrutto,
                  label: 'Bruttopreis (€)',
                  focusNode: fnBrutto,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextField(
                  controller: ctrlNetto,
                  label: 'Nettopreis (€)',
                ),
              ),
            ],
          ),
          const Gap(24),

          Text(
            'Bemerkung',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
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
