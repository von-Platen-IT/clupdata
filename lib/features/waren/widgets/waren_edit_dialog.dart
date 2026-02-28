import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../common_widgets/forms/app_text_field.dart';
import '../../stammdaten/data/stammdaten_repository.dart';
import '../data/waren_repository.dart';
import '../presentation/providers/waren_list_provider.dart';

class WarenEditDialog extends HookConsumerWidget {
  final WarenDetail? details;

  const WarenEditDialog({super.key, this.details});

  static Future<void> show(BuildContext context, {WarenDetail? details}) {
    return showDialog(
      context: context,
      builder: (context) => WarenEditDialog(details: details),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = details != null;

    // Allgemein
    final bezeichnungCtrl = useTextEditingController(text: details?.ware.bezeichnung ?? '');
    final kategorieCtrl = useTextEditingController(text: details?.ware.kategorie ?? '');
    final beschreibungCtrl = useTextEditingController(text: details?.ware.beschreibung ?? '');
    final aktivCtrl = useState<bool>(details?.ware.aktiv ?? true);

    // Eigenschaften
    final groesseCtrl = useTextEditingController(text: details?.ware.groesse ?? '');
    final farbeCtrl = useTextEditingController(text: details?.ware.farbe ?? '');
    final geschlechtCtrl = useState<String?>(details?.ware.geschlecht);
    final materialCtrl = useTextEditingController(text: details?.ware.material ?? '');
    final gewichtCtrl = useTextEditingController(text: details?.ware.gewichtKg?.toString() ?? '');
    final einheitCtrl = useTextEditingController(text: details?.ware.einheit ?? 'Stück');

    // Preise & Bestand
    final einkaufsCtrl = useTextEditingController(text: details?.ware.einkaufspreis?.toString() ?? '');
    final bruttoCtrl = useTextEditingController(text: details?.ware.bruttopreis.toString() ?? '');
    final bestandCtrl = useTextEditingController(text: details?.ware.bestand.toString() ?? '0');
    final minBestandCtrl = useTextEditingController(text: details?.ware.mindestbestand.toString() ?? '0');

    // Logistik
    final lieferantCtrl = useTextEditingController(text: details?.ware.lieferant ?? '');
    final herstellerCtrl = useTextEditingController(text: details?.ware.hersteller ?? '');
    final artikelnrCtrl = useTextEditingController(text: details?.ware.herstellerArtikelnr ?? '');

    // Bemerkung
    final bemerkungTitelCtrl = useTextEditingController(text: details?.bemerkung?.titel ?? '');
    final bemerkungTextCtrl = useTextEditingController(text: details?.bemerkung?.textValue ?? '');

    final isLoadingAsync = useState(false);

    // Watch Stammdaten for live net computation
    final stammdatenAsync = ref.watch(stammdatenSettingsMapForWarenProvider);
    final settings = stammdatenAsync.value ?? {};
    final mwstKey = settings['mwst_aktiv_schluessel'] ?? 'mwst_standard';
    final mwstValueStr = settings[mwstKey] ?? '19';
    final mwstRate = double.tryParse(mwstValueStr) ?? 19.0;

    useListenable(bruttoCtrl);
    final bruttoVal = double.tryParse(bruttoCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final nettoVal = bruttoVal / (1 + (mwstRate / 100));

    Future<void> save() async {
      if (bezeichnungCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bezeichnung ist Pflichtfeld')));
        return;
      }
      final parsedBrutto = double.tryParse(bruttoCtrl.text.replaceAll(',', '.'));
      if (parsedBrutto == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gültiger Bruttopreis benötigt')));
        return;
      }

      final parsedEinkauf = double.tryParse(einkaufsCtrl.text.replaceAll(',', '.'));
      final parsedGewicht = double.tryParse(gewichtCtrl.text.replaceAll(',', '.'));
      final parsedBestand = int.tryParse(bestandCtrl.text) ?? 0;
      final parsedMinBestand = int.tryParse(minBestandCtrl.text) ?? 0;

      isLoadingAsync.value = true;
      try {
        final repo = ref.read(warenRepositoryProvider);
        await repo.saveWareFull(
          wareId: details?.ware.id,
          bezeichnung: bezeichnungCtrl.text.trim(),
          beschreibung: beschreibungCtrl.text.trim(),
          kategorie: kategorieCtrl.text.trim(),
          groesse: groesseCtrl.text.trim(),
          farbe: farbeCtrl.text.trim(),
          geschlecht: geschlechtCtrl.value,
          material: materialCtrl.text.trim(),
          einkaufspreis: parsedEinkauf,
          bruttopreis: parsedBrutto,
          bestand: parsedBestand,
          mindestbestand: parsedMinBestand,
          lieferant: lieferantCtrl.text.trim(),
          hersteller: herstellerCtrl.text.trim(),
          herstellerArtikelnr: artikelnrCtrl.text.trim(),
          gewichtKg: parsedGewicht,
          einheit: einheitCtrl.text.trim(),
          aktiv: aktivCtrl.value,
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
            Text(isEditing ? 'Ware bearbeiten' : 'Neue Ware anlegen'),
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
            width: 800,
            height: 700,
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
                      // --- Allgemein ---
                      const Text('Allgemein', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                      const Divider(),
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: AppTextField(controller: bezeichnungCtrl, label: 'Bezeichnung', required: true),
                          ),
                          const Gap(16),
                          Expanded(
                            flex: 1,
                            child: AppTextField(controller: kategorieCtrl, label: 'Kategorie'),
                          ),
                        ],
                      ),
                      const Gap(16),
                      AppTextField(controller: beschreibungCtrl, label: 'Beschreibung', maxLines: 3, textInputAction: TextInputAction.none),
                      const Gap(8),
                      Row(
                        children: [
                          Checkbox(value: aktivCtrl.value, onChanged: (v) => aktivCtrl.value = v ?? true),
                          const Text('Artikel ist aktiv (im Verkauf)'),
                        ],
                      ),
                      const Gap(32),

                      // --- Eigenschaften ---
                      const Text('Eigenschaften', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                      const Divider(),
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(child: AppTextField(controller: groesseCtrl, label: 'Größe')),
                          const Gap(16),
                          Expanded(child: AppTextField(controller: farbeCtrl, label: 'Farbe')),
                          const Gap(16),
                          Expanded(
                            child: DropdownButtonFormField<String?>(
                              value: geschlechtCtrl.value,
                              decoration: const InputDecoration(labelText: 'Geschlecht', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: null, child: Text('- Keine Angabe -')),
                                DropdownMenuItem(value: 'Unisex', child: Text('Unisex')),
                                DropdownMenuItem(value: 'Herren', child: Text('Herren')),
                                DropdownMenuItem(value: 'Damen', child: Text('Damen')),
                                DropdownMenuItem(value: 'Kinder', child: Text('Kinder')),
                              ],
                              onChanged: (v) => geschlechtCtrl.value = v,
                            ),
                          ),
                        ],
                      ),
                      const Gap(16),
                      Row(
                        children: [
                          Expanded(child: AppTextField(controller: materialCtrl, label: 'Material')),
                          const Gap(16),
                          Expanded(child: AppTextField(controller: gewichtCtrl, label: 'Gewicht (kg)', keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                          const Gap(16),
                          Expanded(child: AppTextField(controller: einheitCtrl, label: 'Einheit (Stück, Paar)')),
                        ],
                      ),
                      const Gap(32),

                      // --- Preise & Bestand ---
                      const Text('Preise & Bestand', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                      const Divider(),
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(child: AppTextField(controller: einkaufsCtrl, label: 'Einkaufspreis Netto (€)', keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                          const Gap(16),
                          Expanded(child: AppTextField(controller: bruttoCtrl, label: 'Verkaufspreis Brutto (€)', required: true, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                          const Gap(16),
                          Expanded(child: AppTextField(controller: TextEditingController(text: nettoVal.toStringAsFixed(2)), label: 'Nettopreis (berechnet)', readOnly: true)),
                        ],
                      ),
                      const Gap(16),
                      Row(
                        children: [
                          Expanded(child: AppTextField(controller: bestandCtrl, label: 'Aktueller Bestand', keyboardType: TextInputType.number)),
                          const Gap(16),
                          Expanded(child: AppTextField(controller: minBestandCtrl, label: 'Mindestbestand', keyboardType: TextInputType.number)),
                          const Gap(16),
                          const Spacer(), // Empty space to align
                        ],
                      ),
                      const Gap(32),

                      // --- Logistik & Hersteller ---
                      const Text('Logistik & Hersteller', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                      const Divider(),
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(child: AppTextField(controller: lieferantCtrl, label: 'Lieferant')),
                          const Gap(16),
                          Expanded(child: AppTextField(controller: herstellerCtrl, label: 'Hersteller')),
                          const Gap(16),
                          Expanded(child: AppTextField(controller: artikelnrCtrl, label: 'Hersteller Artikelnr.')),
                        ],
                      ),
                      const Gap(32),

                      // --- Bemerkung ---
                      const Text('Lokale Bemerkung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                      const Divider(),
                      const Gap(8),
                      AppTextField(controller: bemerkungTitelCtrl, label: 'Bemerkung Titel'),
                      const Gap(16),
                      AppTextField(controller: bemerkungTextCtrl, label: 'Bemerkung Text', maxLines: 4, textInputAction: TextInputAction.none),
                      const Gap(32),
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
