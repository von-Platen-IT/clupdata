import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../common_widgets/forms/app_dropdown_field.dart';
import '../../../../common_widgets/forms/app_date_picker_field.dart';
import '../../../../core/database/database.dart';
import '../data/members_repository.dart';

class MemberEditDialog extends HookConsumerWidget {
  final int? memberId;
  final String? initialFocusField;

  const MemberEditDialog({
    super.key,
    this.memberId,
    this.initialFocusField,
  });

  static Future<void> show(
    BuildContext context, {
    int? memberId,
    String? initialFocusField,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false, // Must use Cancel or X to close
      builder: (context) => MemberEditDialog(
        memberId: memberId,
        initialFocusField: initialFocusField,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Load data
    final memberAsync = useMemoized(() {
      if (memberId == null) return Future.value(null);
      return ref.read(membersRepositoryProvider).getMemberById(memberId!);
    }, [memberId]);
    
    final memberSnapshot = useFuture(memberAsync);
    final bemerkungAsync = useMemoized(() {
      final mId = memberSnapshot.data?.bemerkungId;
      if (mId == null) return Future.value(null);
      return ref.read(membersRepositoryProvider).getBemerkungById(mId);
    }, [memberSnapshot.data?.bemerkungId]);
    final bemerkungSnapshot = useFuture(bemerkungAsync);

    final isLoadingConfig = memberId != null && 
        (memberSnapshot.connectionState == ConnectionState.waiting || 
         bemerkungSnapshot.connectionState == ConnectionState.waiting);

    // 2. Form Controllers
    // Person
    final ctrlAnrede = useTextEditingController();
    final ctrlName = useTextEditingController();
    final ctrlVorname = useTextEditingController();
    final ctrlGeboren = useState<DateTime?>(null);
    final ctrlGeschlecht = useTextEditingController();
    
    // Kontakt
    final ctrlPlz = useTextEditingController();
    final ctrlOrt = useTextEditingController();
    final ctrlStrasse = useTextEditingController();
    final ctrlHausnummer = useTextEditingController();
    final ctrlTelefon1 = useTextEditingController();
    final ctrlTelefon2 = useTextEditingController();
    final ctrlEmail = useTextEditingController();
    
    // Vertrag
    final ctrlVertragKontierung = useState<DateTime?>(null);
    final ctrlVertragLaufzeitVon = useState<DateTime?>(null);
    final ctrlVertragLaufzeitBis = useState<DateTime?>(null);
    
    // Bemerkung
    final ctrlBemerkungTitel = useTextEditingController();
    final ctrlBemerkungText = useTextEditingController();

    // 3. Focus Nodes
    final fnAnrede = useFocusNode();
    final fnName = useFocusNode();
    final fnVorname = useFocusNode();
    final fnGeboren = useFocusNode();
    final fnGeschlecht = useFocusNode();
    final fnPlz = useFocusNode();
    final fnOrt = useFocusNode();
    final fnStrasse = useFocusNode();
    final fnHausnummer = useFocusNode();
    final fnTelefon1 = useFocusNode();
    final fnTelefon2 = useFocusNode();
    final fnEmail = useFocusNode();
    final fnVertragKontierung = useFocusNode();
    final fnVertragLaufzeitVon = useFocusNode();
    final fnVertragLaufzeitBis = useFocusNode();
    
    // 4. Initialize Data
    useEffect(() {
      if (memberSnapshot.hasData) {
        final m = memberSnapshot.data!;
        ctrlAnrede.text = m.anrede ?? '';
        ctrlName.text = m.name;
        ctrlVorname.text = m.vorname;
        ctrlGeboren.value = m.geboren;
        // ctrlGeschlecht.text = m.geschlecht ?? ''; // Not in DB schema yet
        
        ctrlPlz.text = m.plz ?? '';
        ctrlOrt.text = m.ort ?? '';
        ctrlStrasse.text = m.strasse ?? '';
        ctrlHausnummer.text = m.hausnummer ?? '';
        ctrlTelefon1.text = m.telefon1 ?? '';
        ctrlTelefon2.text = m.telefon2 ?? '';
        ctrlEmail.text = m.email ?? '';
        
        ctrlVertragKontierung.value = m.vertragKontierung;
        ctrlVertragLaufzeitVon.value = m.vertragLaufzeitVon;
        ctrlVertragLaufzeitBis.value = m.vertragLaufzeitBis;
      }
      
      if (bemerkungSnapshot.hasData) {
        final b = bemerkungSnapshot.data!;
        ctrlBemerkungTitel.text = b.titel;
        ctrlBemerkungText.text = b.textValue ?? '';
      }
      return null;
    }, [memberSnapshot.data, bemerkungSnapshot.data]);

    // 5. Auto Focus based on initialFocusField
    useEffect(() {
      if (!isLoadingConfig && initialFocusField != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          switch (initialFocusField) {
            case 'name': fnName.requestFocus(); break;
            case 'vorname': fnVorname.requestFocus(); break;
            case 'ort': fnOrt.requestFocus(); break;
            case 'telefon1': fnTelefon1.requestFocus(); break;
            case 'email': fnEmail.requestFocus(); break;
            case 'vertrag_laufzeit_von': fnVertragLaufzeitVon.requestFocus(); break;
            case 'vertrag_laufzeit_bis': fnVertragLaufzeitBis.requestFocus(); break;
            // Add more mappings if needed based on AppDataGrid columns
          }
        });
      }
      return null;
    }, [isLoadingConfig, initialFocusField]);

    final isSaving = useState(false);

    // Save Action
    Future<void> saveMember() async {
      // Very basic validation
      if (ctrlName.text.isEmpty || ctrlVorname.text.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name und Vorname sind Pflichtfelder.')));
         return;
      }

      isSaving.value = true;
      try {
        final repo = ref.read(membersRepositoryProvider);
        
        // 1. Save member
        final companion = MitgliedsCompanion(
           id: memberId != null ? drift.Value(memberId!) : const drift.Value.absent(),
           anrede: drift.Value(ctrlAnrede.text.isEmpty ? null : ctrlAnrede.text),
           name: drift.Value(ctrlName.text),
           vorname: drift.Value(ctrlVorname.text),
           geboren: drift.Value(ctrlGeboren.value),
           // geschlecht: drift.Value(ctrlGeschlecht.text.isEmpty ? null : ctrlGeschlecht.text), // Not in DB schema yet
           plz: drift.Value(ctrlPlz.text.isEmpty ? null : ctrlPlz.text),
           ort: drift.Value(ctrlOrt.text.isEmpty ? null : ctrlOrt.text),
           strasse: drift.Value(ctrlStrasse.text.isEmpty ? null : ctrlStrasse.text),
           hausnummer: drift.Value(ctrlHausnummer.text.isEmpty ? null : ctrlHausnummer.text),
           telefon1: drift.Value(ctrlTelefon1.text.isEmpty ? null : ctrlTelefon1.text),
           telefon2: drift.Value(ctrlTelefon2.text.isEmpty ? null : ctrlTelefon2.text),
           email: drift.Value(ctrlEmail.text.isEmpty ? null : ctrlEmail.text),
           vertragKontierung: drift.Value(ctrlVertragKontierung.value),
           vertragLaufzeitVon: drift.Value(ctrlVertragLaufzeitVon.value),
           vertragLaufzeitBis: drift.Value(ctrlVertragLaufzeitBis.value),
        );

        int savedMemberId;
        if (memberId == null) {
           savedMemberId = await repo.addMember(companion);
        } else {
           await repo.updateMember(Mitglied(
              id: memberId!,
              name: ctrlName.text,
              vorname: ctrlVorname.text,
              anrede: companion.anrede.value,
              geboren: companion.geboren.value,
              // geschlecht: companion.geschlecht.value, // Not in DB schema yet
              plz: companion.plz.value,
              ort: companion.ort.value,
              strasse: companion.strasse.value,
              hausnummer: companion.hausnummer.value,
              telefon1: companion.telefon1.value,
              telefon2: companion.telefon2.value,
              email: companion.email.value,
              vertragKontierung: companion.vertragKontierung.value,
              vertragLaufzeitVon: companion.vertragLaufzeitVon.value,
              vertragLaufzeitBis: companion.vertragLaufzeitBis.value,
              leistungId: memberSnapshot.data?.leistungId,
              bemerkungId: memberSnapshot.data?.bemerkungId,
           ));
           savedMemberId = memberId!;
        }

        // 2. Save bemerkung if not empty
        final bemerkungTitel = ctrlBemerkungTitel.text.trim();
        final bemerkungText = ctrlBemerkungText.text.trim();
        if (bemerkungTitel.isNotEmpty || bemerkungText.isNotEmpty) {
           await repo.saveMemberRemark(
             savedMemberId, 
             memberSnapshot.data?.bemerkungId, 
             bemerkungTitel.isNotEmpty ? bemerkungTitel : 'Bemerkung', 
             bemerkungText,
           );
        }

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
            saveMember();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(memberId == null ? 'Neues Mitglied' : 'Mitglied bearbeiten'),
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
               // Section Person
               Text('Person', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
               const Gap(8),
               AppDropdownField<String>(
                  controller: ctrlAnrede,
                  label: 'Anrede',
                  focusNode: fnAnrede,
                  options: const ['Herr', 'Frau', 'Divers', 'Keine'],
                  getLabel: (v) => v,
               ),
               const Gap(8),
               Row(
                 children: [
                   Expanded(child: AppTextField(controller: ctrlVorname, label: 'Vorname', focusNode: fnVorname)),
                   const Gap(8),
                   Expanded(child: AppTextField(controller: ctrlName, label: 'Name', focusNode: fnName)),
                 ],
               ),
               const Gap(8),
               Row(
                 children: [
                    Expanded(child: AppDatePickerField(
                       value: ctrlGeboren.value,
                       onChanged: (v) => ctrlGeboren.value = v,
                       label: 'Geburtsdatum',
                       focusNode: fnGeboren,
                    )),
                    const Gap(8),
                    Expanded(child: AppDropdownField<String>(
                       controller: ctrlGeschlecht,
                       label: 'Geschlecht',
                       focusNode: fnGeschlecht,
                       options: const ['maennlich', 'weiblich', 'divers'],
                       getLabel: (v) => v,
                    )),
                 ],
               ),
               const Gap(24),
               
               // Section Kontakt
               Text('Kontakt', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
               const Gap(8),
               Row(
                 children: [
                   Expanded(flex: 3, child: AppTextField(controller: ctrlStrasse, label: 'Straße', focusNode: fnStrasse)),
                   const Gap(8),
                   Expanded(flex: 1, child: AppTextField(controller: ctrlHausnummer, label: 'Hausnummer', focusNode: fnHausnummer)),
                 ],
               ),
               const Gap(8),
               Row(
                 children: [
                   Expanded(flex: 1, child: AppTextField(controller: ctrlPlz, label: 'PLZ', focusNode: fnPlz)),
                   const Gap(8),
                   Expanded(flex: 3, child: AppTextField(controller: ctrlOrt, label: 'Ort', focusNode: fnOrt)),
                 ],
               ),
               const Gap(8),
               Row(
                 children: [
                   Expanded(child: AppTextField(controller: ctrlTelefon1, label: 'Telefon 1', focusNode: fnTelefon1)),
                   const Gap(8),
                   Expanded(child: AppTextField(controller: ctrlTelefon2, label: 'Telefon 2', focusNode: fnTelefon2)),
                 ],
               ),
               const Gap(8),
               AppTextField(controller: ctrlEmail, label: 'E-Mail', focusNode: fnEmail),
               const Gap(24),

               // Section Vertrag
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                    Text('Vertrag', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ElevatedButton(onPressed: () {}, child: const Text('Vertragsaktion')), // Placeholder for vertrag_start_action
                 ],
               ),
               const Gap(8),
               AppDatePickerField(
                  value: ctrlVertragKontierung.value,
                  onChanged: (v) => ctrlVertragKontierung.value = v,
                  label: 'Kontierung',
                  focusNode: fnVertragKontierung,
               ),
               const Gap(8),
               Row(
                 children: [
                    Expanded(child: AppDatePickerField(
                       value: ctrlVertragLaufzeitVon.value,
                       onChanged: (v) => ctrlVertragLaufzeitVon.value = v,
                       label: 'Laufzeit von',
                       focusNode: fnVertragLaufzeitVon,
                    )),
                    const Gap(8),
                    Expanded(child: AppDatePickerField(
                       value: ctrlVertragLaufzeitBis.value,
                       onChanged: (v) => ctrlVertragLaufzeitBis.value = v,
                       label: 'Laufzeit bis',
                       focusNode: fnVertragLaufzeitBis,
                    )),
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
        if (memberId != null)
           TextButton.icon(
             icon: const Icon(Icons.delete, color: Colors.red),
             label: const Text('Löschen', style: TextStyle(color: Colors.red)),
             onPressed: () async {
               final confirm = await showDialog<bool>(
                 context: context,
                 builder: (ctx) => AlertDialog(
                   title: const Text('Wirklich löschen?'),
                   content: const Text('Möchten Sie dieses Mitglied unwiderruflich löschen?'),
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
                   await ref.read(membersRepositoryProvider).deleteMember(memberId!);
                   if (context.mounted) {
                     Navigator.of(context).pop();
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mitglied erfolgreich gelöscht')));
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
              onPressed: isSaving.value ? null : saveMember,
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
