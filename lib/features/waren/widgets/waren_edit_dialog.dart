import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../common_widgets/forms/app_dropdown_field.dart';
import '../data/waren_repository.dart';
import '../presentation/providers/waren_list_provider.dart';

class WarenEditDialog extends HookConsumerWidget {
  final int? wareId;
  final String? initialFocusField;

  const WarenEditDialog({
    super.key,
    this.wareId,
    this.initialFocusField,
  });

  static Future<void> show(
    BuildContext context, {
    int? wareId,
    String? initialFocusField,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WarenEditDialog(
        wareId: wareId,
        initialFocusField: initialFocusField,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(watchWarenDetailsProvider);
    final detailsList = detailsAsync.value ?? [];
    final details = wareId != null ? detailsList.where((d) => d.ware.id == wareId).firstOrNull : null;
    
    final settingsAsync = ref.watch(stammdatenSettingsMapForWarenProvider);
    final mwstRate = useMemoized(() {
      final settings = settingsAsync.value ?? {};
      final mwstKey = settings['mwst_aktiv_schluessel'] ?? 'mwst_standard';
      return double.tryParse(settings[mwstKey] ?? '19') ?? 19.0;
    }, [settingsAsync.value]);

    final mwstMultiplier = 1 + (mwstRate / 100);

    final isLoadingConfig = wareId != null && detailsAsync.isLoading;

    // 2. Controllers - Allgemein
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

    // 3. Focus Nodes
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

    // 4. Initialization
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
          ctrlNettopreis.text = (w.bruttopreis / mwstMultiplier).toStringAsFixed(2);
          ctrlBestand.text = w.bestand.toString();
          ctrlMindestbestand.text = w.mindestbestand.toString();

          ctrlLieferant.text = w.lieferant ?? '';
          ctrlHersteller.text = w.hersteller ?? '';
          ctrlHerstellerArtikelnr.text = w.herstellerArtikelnr ?? '';

          final b = details.bemerkung;
          ctrlBemerkungTitel.text = b?.titel ?? '';
          ctrlBemerkungText.text = b?.textValue ?? '';
       } else {
          // Defaults for new item
          ctrlBestand.text = '0';
          ctrlMindestbestand.text = '0';
       }
       return null;
    }, [details, mwstMultiplier]);

    // Track active updates to avoid loop
    final isUpdatingPrice = useState(false);

    useEffect(() {
      void updateNetto() {
        if (isUpdatingPrice.value) return;
        final bruttoVal = double.tryParse(ctrlBruttopreis.text.replaceAll(',', '.'));
        if (bruttoVal != null) {
          isUpdatingPrice.value = true;
          ctrlNettopreis.text = (bruttoVal / mwstMultiplier).toStringAsFixed(2);
          isUpdatingPrice.value = false;
        } else if (ctrlBruttopreis.text.isEmpty) {
          isUpdatingPrice.value = true;
          ctrlNettopreis.text = '';
          isUpdatingPrice.value = false;
        }
      }

      void updateBrutto() {
        if (isUpdatingPrice.value) return;
        final nettoVal = double.tryParse(ctrlNettopreis.text.replaceAll(',', '.'));
        if (nettoVal != null) {
          isUpdatingPrice.value = true;
          ctrlBruttopreis.text = (nettoVal * mwstMultiplier).toStringAsFixed(2);
          isUpdatingPrice.value = false;
        } else if (ctrlNettopreis.text.isEmpty) {
          isUpdatingPrice.value = true;
          ctrlBruttopreis.text = '';
          isUpdatingPrice.value = false;
        }
      }

      ctrlBruttopreis.addListener(updateNetto);
      ctrlNettopreis.addListener(updateBrutto);

      return () {
        ctrlBruttopreis.removeListener(updateNetto);
        ctrlNettopreis.removeListener(updateBrutto);
      };
    }, [mwstMultiplier]);

    // 5. Auto Focus
    useEffect(() {
      if (!isLoadingConfig && initialFocusField != null) {
         WidgetsBinding.instance.addPostFrameCallback((_) {
            switch (initialFocusField) {
              case 'bezeichnung': fnBezeichnung.requestFocus(); break;
              case 'kategorie': fnKategorie.requestFocus(); break;
              case 'bestand': fnBestand.requestFocus(); break;
              case 'bruttopreis': fnBruttopreis.requestFocus(); break;
            }
         });
      }
      return null;
    }, [isLoadingConfig, initialFocusField]);

    final isSaving = useState(false);

    Future<void> saveWare() async {
      if (ctrlBezeichnung.text.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bezeichnung ist ein Pflichtfeld.')));
         return;
      }

      final bruttoVal = double.tryParse(ctrlBruttopreis.text.replaceAll(',', '.'));
      if (bruttoVal == null) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ungültiger Bruttopreis.')));
         return;
      }

      isSaving.value = true;
      try {
        final repo = ref.read(warenRepositoryProvider);

        await repo.saveWareFull(
          wareId: wareId,
          bezeichnung: ctrlBezeichnung.text,
          beschreibung: ctrlBeschreibung.text,
          kategorie: ctrlKategorie.text,
          groesse: ctrlGroesse.text,
          farbe: ctrlFarbe.text,
          geschlecht: ctrlGeschlecht.text,
          material: ctrlMaterial.text,
          einkaufspreis: double.tryParse(ctrlEinkaufspreis.text.replaceAll(',', '.')),
          bruttopreis: bruttoVal,
          bestand: int.tryParse(ctrlBestand.text) ?? 0,
          mindestbestand: int.tryParse(ctrlMindestbestand.text) ?? 0,
          lieferant: ctrlLieferant.text,
          hersteller: ctrlHersteller.text,
          herstellerArtikelnr: ctrlHerstellerArtikelnr.text,
          gewichtKg: double.tryParse(ctrlGewichtKg.text.replaceAll(',', '.')),
          einheit: ctrlEinheit.text,
          aktiv: ctrlAktiv.value,
          existingBemerkungId: details?.bemerkung?.id,
          bemerkungTitel: ctrlBemerkungTitel.text,
          bemerkungText: ctrlBemerkungText.text,
        );

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erfolgreich gespeichert')));
        }
      } catch (e) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
        }
      } finally {
        isSaving.value = false;
      }
    }

    if (isLoadingConfig) {
       return const AlertDialog(content: SizedBox(width: 100, height: 100, child: Center(child: CircularProgressIndicator())));
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!isSaving.value) {
            saveWare();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(wareId == null ? 'Neue Ware' : 'Ware bearbeiten'),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: SizedBox(
        width: 800,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               // Allgemein
               Text('Allgemein', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
               const Gap(8),
               Row(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Expanded(flex: 3, child: AppTextField(controller: ctrlBezeichnung, label: 'Bezeichnung', focusNode: fnBezeichnung)),
                   const Gap(8),
                   Expanded(flex: 2, child: AppTextField(controller: ctrlKategorie, label: 'Kategorie', focusNode: fnKategorie)),
                 ],
               ),
               const Gap(8),
               AppTextField(controller: ctrlBeschreibung, label: 'Beschreibung', focusNode: fnBeschreibung, maxLines: 2),
               const Gap(8),
               Row(
                 children: [
                   Checkbox(value: ctrlAktiv.value, onChanged: (v) => ctrlAktiv.value = v ?? false),
                   const Text('Aktiv (für Verkauf verfügbar)'),
                 ],
               ),
               const Gap(24),

               // Eigenschaften
               Text('Eigenschaften', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
               const Gap(8),
               Row(
                 children: [
                   Expanded(child: AppTextField(controller: ctrlGroesse, label: 'Größe', focusNode: fnGroesse)),
                   const Gap(8),
                   Expanded(child: AppTextField(controller: ctrlFarbe, label: 'Farbe', focusNode: fnFarbe)),
                   const Gap(8),
                   Expanded(child: AppDropdownField<String>(
                      controller: ctrlGeschlecht,
                      label: 'Geschlecht',
                      focusNode: fnGeschlecht,
                      options: const ['Unisex', 'Herren', 'Damen', 'Kinder'],
                      getLabel: (v) => v,
                   )),
                 ],
               ),
               const Gap(8),
               Row(
                 children: [
                   Expanded(child: AppTextField(controller: ctrlMaterial, label: 'Material', focusNode: fnMaterial)),
                   const Gap(8),
                   Expanded(child: AppTextField(controller: ctrlGewichtKg, label: 'Gewicht (kg)', focusNode: fnGewichtKg)),
                   const Gap(8),
                   Expanded(child: AppTextField(controller: ctrlEinheit, label: 'Einheit', focusNode: fnEinheit)),
                 ],
               ),
               const Gap(24),

               // Preise & Bestand
               Text('Preise & Bestand', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
               const Gap(8),
               Row(
                 children: [
                   Expanded(child: AppTextField(controller: ctrlEinkaufspreis, label: 'Einkaufspreis (€)', focusNode: fnEinkaufspreis)),
                   const Gap(8),
                   Expanded(child: AppTextField(controller: ctrlBruttopreis, label: 'VK Brutto', focusNode: fnBruttopreis)),
                   const Gap(8),
                   Expanded(child: AppTextField(controller: ctrlNettopreis, label: 'VK Netto')),
                 ],
               ),
               const Gap(8),
               Row(
                 children: [
                   Expanded(child: AppTextField(controller: ctrlBestand, label: 'Bestand', focusNode: fnBestand)),
                   const Gap(8),
                   Expanded(child: AppTextField(controller: ctrlMindestbestand, label: 'Mindestbestand', focusNode: fnMindestbestand)),
                 ],
               ),
               const Gap(24),

               // Logistik
               Text('Logistik & Hersteller', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
               const Gap(8),
               Row(
                 children: [
                   Expanded(child: AppTextField(controller: ctrlLieferant, label: 'Lieferant', focusNode: fnLieferant)),
                   const Gap(8),
                   Expanded(child: AppTextField(controller: ctrlHersteller, label: 'Hersteller', focusNode: fnHersteller)),
                   const Gap(8),
                   Expanded(child: AppTextField(controller: ctrlHerstellerArtikelnr, label: 'Artikelnr. HF', focusNode: fnHerstellerArtikelnr)),
                 ],
               ),
               const Gap(24),

               // Bemerkung
               Text('Bemerkung', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
               const Gap(8),
               AppTextField(controller: ctrlBemerkungTitel, label: 'Titel'),
               const Gap(8),
               AppTextField(controller: ctrlBemerkungText, label: 'Text', maxLines: 3),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        if (wareId != null)
           TextButton.icon(
             icon: const Icon(Icons.delete, color: Colors.red),
             label: const Text('Löschen', style: TextStyle(color: Colors.red)),
             onPressed: () async {
               final confirm = await showDialog<bool>(
                 context: context,
                 builder: (ctx) => AlertDialog(
                   title: const Text('Wirklich löschen?'),
                   content: const Text('Möchten Sie diese Ware unwiderruflich löschen?'),
                   actions: [
                     TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Abbrechen')),
                     FilledButton(
                       style: FilledButton.styleFrom(backgroundColor: Colors.red),
                       onPressed: () => Navigator.of(ctx).pop(true), 
                       child: const Text('Löschen'),
                     ),
                   ]
                 )
               );
               if (confirm == true && context.mounted) {
                 try {
                   await ref.read(warenRepositoryProvider).deleteWare(wareId!);
                   if (context.mounted) {
                     Navigator.of(context).pop();
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ware erfolgreich gelöscht')));
                   }
                 } catch (e) {
                   if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Löschen: $e')));
                   }
                 }
               }
             },
           )
        else
           const SizedBox.shrink(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            const Gap(8),
            FilledButton.icon(
              onPressed: isSaving.value ? null : saveWare,
              icon: isSaving.value 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: const Text('Speichern'),
            ),
          ],
        ),
      ],
        ),
      ),
    );
  }
}
