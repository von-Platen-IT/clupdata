import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../common_widgets/forms/app_text_field.dart';
import '../../stammdaten/data/stammdaten_repository.dart';
import '../data/leistungen_repository.dart';
import '../presentation/providers/leistungen_list_provider.dart';

class LeistungEditDialog extends HookConsumerWidget {
  final LeistungsDetail? details;

  const LeistungEditDialog({super.key, this.details});

  static Future<void> show(BuildContext context, {LeistungsDetail? details}) {
    return showDialog(
      context: context,
      builder: (context) => LeistungEditDialog(details: details),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = details != null;

    final nameCtrl = useTextEditingController(text: details?.leistung.name ?? '');
    final laufzeitCtrl = useState<String>(details?.leistung.laufzeit ?? 'monatlich');
    final bruttoCtrl = useTextEditingController(text: details?.preis.bruttopreis.toString() ?? '');
    
    final bemerkungTitelCtrl = useTextEditingController(text: details?.bemerkung?.titel ?? '');
    final bemerkungTextCtrl = useTextEditingController(text: details?.bemerkung?.textValue ?? '');

    final isLoadingAsync = useState(false);

    // Watch Stammdaten for live net computation
    final stammdatenAsync = ref.watch(stammdatenSettingsMapProvider);
    final settings = stammdatenAsync.value ?? {};
    final mwstKey = settings['mwst_aktiv_schluessel'] ?? 'mwst_standard';
    final mwstValueStr = settings[mwstKey] ?? '19';
    final mwstRate = double.tryParse(mwstValueStr) ?? 19.0;

    useListenable(bruttoCtrl);
    final bruttoVal = double.tryParse(bruttoCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final nettoVal = bruttoVal / (1 + (mwstRate / 100));

    Future<void> save() async {
      if (nameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name ist Pflichtfeld')));
        return;
      }
      final parsedBrutto = double.tryParse(bruttoCtrl.text.replaceAll(',', '.'));
      if (parsedBrutto == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gültiger Bruttopreis benötigt')));
        return;
      }

      isLoadingAsync.value = true;
      try {
        final repo = ref.read(leistungenRepositoryProvider);
        await repo.saveLeistungFull(
          leistungId: details?.leistung.id,
          name: nameCtrl.text.trim(),
          laufzeit: laufzeitCtrl.value,
          existingPreisId: details?.preis.id,
          bruttopreis: parsedBrutto,
          existingBemerkungId: details?.bemerkung?.id,
          bemerkungTitel: bemerkungTitelCtrl.text.trim(),
          bemerkungText: bemerkungTextCtrl.text.trim(),
        );
        if (context.mounted) Navigator.of(context).pop();
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      } finally {
        if (context.mounted) isLoadingAsync.value = false;
      }
    }

    final scrollController = useScrollController();

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isEditing ? 'Leistung bearbeiten' : 'Neue Leistung anlegen'),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
              splashRadius: 20,
            ),
          ],
        ),
        content: FocusTraversalOrder(
          order: const NumericFocusOrder(1),
          child: SizedBox(
            width: 600,
            height: 500,
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Leistung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Divider(),
                      const Gap(8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: nameCtrl,
                              label: 'Name',
                              required: true,
                            ),
                          ),
                          const Gap(16),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              value: laufzeitCtrl.value,
                              decoration: const InputDecoration(labelText: 'Laufzeit', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'einmalig', child: Text('einmalig')),
                                DropdownMenuItem(value: 'monatlich', child: Text('monatlich')),
                                DropdownMenuItem(value: 'quartalsweise', child: Text('quartalsweise')),
                                DropdownMenuItem(value: 'jaehrlich', child: Text('jährlich')),
                              ],
                              onChanged: (v) => laufzeitCtrl.value = v ?? 'monatlich',
                            ),
                          ),
                        ],
                      ),
                      const Gap(32),

                      const Text('Preis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Divider(),
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: bruttoCtrl,
                              label: 'Bruttopreis (€)',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              required: true,
                            ),
                          ),
                          const Gap(16),
                          Expanded(
                            child: AppTextField(
                              controller: TextEditingController(text: nettoVal.toStringAsFixed(2)),
                              label: 'Nettopreis (€) [bei $mwstRate% MwSt]',
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const Gap(32),

                      const Text('Bemerkung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Divider(),
                      const Gap(8),
                      AppTextField(
                        controller: bemerkungTitelCtrl,
                        label: 'Bemerkung Titel',
                      ),
                      const Gap(16),
                      AppTextField(
                        controller: bemerkungTextCtrl,
                        label: 'Bemerkung Text',
                        maxLines: 4,
                        textInputAction: TextInputAction.none,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        actions: [
          FocusTraversalOrder(
            order: const NumericFocusOrder(2),
            child: TextButton(
              onPressed: isLoadingAsync.value ? null : () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
          ),
          FocusTraversalOrder(
            order: const NumericFocusOrder(3),
            child: ElevatedButton(
              onPressed: isLoadingAsync.value ? null : save,
              child: isLoadingAsync.value
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Speichern'),
            ),
          ),
        ],
      ),
    );
  }
}
