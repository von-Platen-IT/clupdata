import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../common_widgets/forms/app_text_field.dart';
import 'package:gap/gap.dart';

import '../../../core/database/database.dart';
import '../data/members_repository.dart';

/// Modal dialog for creating or editing a member.
class MemberEditDialog extends HookConsumerWidget {
  final Mitglied? member;

  const MemberEditDialog({super.key, this.member});

  static Future<void> show(BuildContext context, {Mitglied? member}) {
    return showDialog(
      context: context,
      builder: (context) => MemberEditDialog(member: member),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = member != null;

    // Helper functions for date formatting and parsing
    String formatDate(DateTime? date) {
      if (date == null) return '';
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }

    DateTime? parseDateLocal(String text) {
      final t = text.trim();
      if (t.isEmpty) return null;
      final parts = t.split(RegExp(r'[\.\-\/]')); // robust split
      if (parts.length == 3) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        int? y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) {
          if (y < 100) y += 2000; // heuristic for 2 digit years
          return DateTime(y, m, d);
        }
      }
      return null;
    }

    // --- State controllers ---
    final anredeCtrl = useState<String?>(member?.anrede);
    final vornameCtrl = useTextEditingController(text: member?.vorname ?? '');
    final nameCtrl = useTextEditingController(text: member?.name ?? '');
    final geborenCtrl = useTextEditingController(text: formatDate(member?.geboren));

    final strasseCtrl = useTextEditingController(text: member?.strasse ?? '');
    final hausnummerCtrl = useTextEditingController(text: member?.hausnummer ?? '');
    final plzCtrl = useTextEditingController(text: member?.plz ?? '');
    final ortCtrl = useTextEditingController(text: member?.ort ?? '');
    final telefon1Ctrl = useTextEditingController(text: member?.telefon1 ?? '');
    final telefon2Ctrl = useTextEditingController(text: member?.telefon2 ?? '');
    final emailCtrl = useTextEditingController(text: member?.email ?? '');

    final leistungIdCtrl = useState<int?>(member?.leistungId);
    final vertragKontierungCtrl = useTextEditingController(text: formatDate(member?.vertragKontierung ?? DateTime.now()));
    final vertragLaufzeitVonCtrl = useTextEditingController(text: formatDate(member?.vertragLaufzeitVon));
    final vertragLaufzeitBisCtrl = useTextEditingController(text: formatDate(member?.vertragLaufzeitBis));
    
    final bemerkungTitelCtrl = useTextEditingController(text: '');
    final bemerkungTextCtrl = useTextEditingController(text: '');

    useEffect(() {
      if (isEditing && member!.bemerkungId != null) {
        ref.read(membersRepositoryProvider).getBemerkungById(member!.bemerkungId!).then((b) {
          if (b != null && context.mounted) {
            bemerkungTitelCtrl.text = b.titel;
            bemerkungTextCtrl.text = b.textValue ?? '';
          }
        });
      }
      return null;
    }, []);

    final isLoadingAsync = useState(false);

    Future<void> selectDate(BuildContext context, TextEditingController ctrl) async {
      final initial = parseDateLocal(ctrl.text) ?? DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked != null) {
        ctrl.text = formatDate(picked);
      }
    }

    Future<void> save() async {
      if (vornameCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vorname und Nachname sind Pflichtfelder')),
        );
        return;
      }

      isLoadingAsync.value = true;
      try {
        final repo = ref.read(membersRepositoryProvider);
        
        final companion = MitgliedsCompanion.insert(
            anrede: drift.Value(anredeCtrl.value),
            vorname: vornameCtrl.text.trim(),
            name: nameCtrl.text.trim(),
            strasse: drift.Value(strasseCtrl.text.trim()),
            hausnummer: drift.Value(hausnummerCtrl.text.trim()),
            plz: drift.Value(plzCtrl.text.trim()),
            ort: drift.Value(ortCtrl.text.trim()),
            telefon1: drift.Value(telefon1Ctrl.text.trim()),
            telefon2: drift.Value(telefon2Ctrl.text.trim()),
            email: drift.Value(emailCtrl.text.trim()),
            geboren: drift.Value(parseDateLocal(geborenCtrl.text)),
            leistungId: drift.Value(leistungIdCtrl.value),
            vertragKontierung: drift.Value(parseDateLocal(vertragKontierungCtrl.text)),
            vertragLaufzeitVon: drift.Value(parseDateLocal(vertragLaufzeitVonCtrl.text)),
            vertragLaufzeitBis: drift.Value(parseDateLocal(vertragLaufzeitBisCtrl.text)),
        );

        int? bemerkungId = member?.bemerkungId;
        final title = bemerkungTitelCtrl.text.trim();
        final text = bemerkungTextCtrl.text.trim();
        if (title.isNotEmpty || text.isNotEmpty) {
           bemerkungId = await repo.saveBemerkung(bemerkungId, title, text);
        }

        final finalCompanion = companion.copyWith(
          bemerkungId: drift.Value(bemerkungId),
        );

        if (isEditing) {
          final updated = member!.copyWith(
            anrede: finalCompanion.anrede,
            vorname: finalCompanion.vorname.value,
            name: finalCompanion.name.value,
            strasse: finalCompanion.strasse,
            hausnummer: finalCompanion.hausnummer,
            plz: finalCompanion.plz,
            ort: finalCompanion.ort,
            telefon1: finalCompanion.telefon1,
            telefon2: finalCompanion.telefon2,
            email: finalCompanion.email,
            geboren: finalCompanion.geboren,
            leistungId: finalCompanion.leistungId,
            vertragKontierung: finalCompanion.vertragKontierung,
            vertragLaufzeitVon: finalCompanion.vertragLaufzeitVon,
            vertragLaufzeitBis: finalCompanion.vertragLaufzeitBis,
            bemerkungId: finalCompanion.bemerkungId,
          );
          await repo.updateMember(updated);
        } else {
          await repo.addMember(finalCompanion);
        }
        
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Speichern: $e')),
          );
        }
      } finally {
        if (context.mounted) {
          isLoadingAsync.value = false;
        }
      }
    }

    final scrollController = useScrollController();

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isEditing ? 'Mitglied bearbeiten' : 'Neues Mitglied anlegen'),
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
            width: 700,
            height: 600, // Make it tall enough but scrollable inside constraints
            child: Scrollbar(
              controller: scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0), // Padding to avoid scrollbar overlap
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Sektion: Person ---
                      const Text('Person', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Divider(),
                      const Gap(8),
                      SizedBox(
                        width: 250,
                        child: DropdownButtonFormField<String>(
                          value: anredeCtrl.value,
                          decoration: const InputDecoration(labelText: 'Anrede', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: null, child: Text('- Keine -')),
                            DropdownMenuItem(value: 'Herr', child: Text('Herr')),
                            DropdownMenuItem(value: 'Frau', child: Text('Frau')),
                            DropdownMenuItem(value: 'Divers', child: Text('Divers')),
                          ],
                          onChanged: (val) => anredeCtrl.value = val,
                        ),
                      ),
                      const Gap(16),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: vornameCtrl,
                              label: 'Vorname',
                              required: true,
                            ),
                          ),
                          const Gap(16),
                          Expanded(
                            child: AppTextField(
                              controller: nameCtrl,
                              label: 'Nachname',
                              required: true,
                            ),
                          ),
                        ],
                      ),
                      const Gap(16),
                      AppTextField(
                        controller: geborenCtrl,
                        label: 'Geburtsdatum (TT.MM.JJJJ)',
                        keyboardType: TextInputType.datetime,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => selectDate(context, geborenCtrl),
                        ),
                      ),
                      
                      const Gap(32),
        
                      // --- Sektion: Kontakt ---
                      const Text('Kontakt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Divider(),
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: AppTextField(
                              controller: strasseCtrl,
                              label: 'Straße',
                            ),
                          ),
                          const Gap(16),
                          Expanded(
                            flex: 1,
                            child: AppTextField(
                              controller: hausnummerCtrl,
                              label: 'Nr.',
                            ),
                          ),
                        ],
                      ),
                      const Gap(16),
                      Row(
                        children: [
                           Expanded(
                            flex: 1,
                            child: AppTextField(
                              controller: plzCtrl,
                              label: 'PLZ',
                            ),
                          ),
                          const Gap(16),
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: ortCtrl,
                              label: 'Ort',
                            ),
                          ),
                        ],
                      ),
                      const Gap(16),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: telefon1Ctrl,
                              label: 'Telefon 1',
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const Gap(16),
                          Expanded(
                            child: AppTextField(
                              controller: telefon2Ctrl,
                              label: 'Telefon 2',
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const Gap(16),
                      AppTextField(
                        controller: emailCtrl,
                        label: 'E-Mail',
                        keyboardType: TextInputType.emailAddress,
                      ),
        
                      const Gap(32),
        
                      // --- Sektion: Vertrag ---
                      if (isEditing) ...[
                        const Text('Vertrag', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Divider(),
                        const Gap(8),
                        AppTextField(
                          controller: vertragKontierungCtrl,
                          label: 'Kontierung (TT.MM.JJJJ)',
                          keyboardType: TextInputType.datetime,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () => selectDate(context, vertragKontierungCtrl),
                          ),
                        ),
                        const Gap(16),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: vertragLaufzeitVonCtrl,
                                label: 'Laufzeit von (TT.MM.JJJJ)',
                                keyboardType: TextInputType.datetime,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: () => selectDate(context, vertragLaufzeitVonCtrl),
                                ),
                              ),
                            ),
                            const Gap(16),
                            Expanded(
                              child: AppTextField(
                                controller: vertragLaufzeitBisCtrl,
                                label: 'Laufzeit bis (TT.MM.JJJJ)',
                                keyboardType: TextInputType.datetime,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.calendar_today),
                                  onPressed: () => selectDate(context, vertragLaufzeitBisCtrl),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const Gap(32),
                      ],
        
                      // --- Sektion: Bemerkung ---
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
