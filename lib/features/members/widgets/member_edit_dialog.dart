import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../common_widgets/app_section_header.dart';
import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../common_widgets/forms/app_dropdown_field.dart';
import '../../../../common_widgets/forms/app_date_picker_field.dart';
import '../../../../core/database/database.dart';
import '../../leistungen/presentation/providers/leistungen_list_provider.dart';
import '../../leistungen/domain/models/leistung_row_data.dart';
import '../../leistungen/data/preise_repository.dart';
import '../data/members_repository.dart';
import '../../export/domain/export_config.dart';

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';

/// Modal dialog for creating and editing a [Mitglied] record.
/// Triggered by double-clicking a row in [MemberDataGrid] or via the "Neu" button.
class MemberEditDialog extends HookConsumerWidget {
  /// ID of the existing member to edit, or `null` when creating a new one.
  final int? memberId;

  /// The field name of the cell that was double-clicked, used to set
  /// initial keyboard focus on the corresponding input widget.
  final String? initialFocusField;

  const MemberEditDialog({super.key, this.memberId, this.initialFocusField});

  /// Opens the dialog. Passes [memberId] for edit mode or omits it for create mode.
  static Future<void> show(
    BuildContext context, {
    int? memberId,
    String? initialFocusField,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MemberEditDialog(
        memberId: memberId,
        initialFocusField: initialFocusField,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Data Loading ───────────────────────────────────────────────────────
    final memberAsync = useMemoized(() {
      if (memberId == null) return Future<Mitglied?>.value(null);
      return ref.read(membersRepositoryProvider).getMemberById(memberId!);
    }, [memberId]);

    final memberSnapshot = useFuture(memberAsync);
    final bemerkungAsync = useMemoized(() {
      final mId = memberSnapshot.data?.bemerkungId;
      if (mId == null) return Future<BemerkungData?>.value(null);
      return ref.read(membersRepositoryProvider).getBemerkungById(mId);
    }, [memberSnapshot.data?.bemerkungId]);
    final bemerkungSnapshot = useFuture(bemerkungAsync);

    final preisAsync = useMemoized(() {
      final pId = memberSnapshot.data?.preisId;
      if (pId == null) return Future<PreisItem?>.value(null);
      return ref.read(preiseRepositoryProvider).getPreisById(pId);
    }, [memberSnapshot.data?.preisId]);
    final preisSnapshot = useFuture(preisAsync);

    final leistungenAsync = ref.watch(leistungenGridRowsProvider);
    final leistungen = leistungenAsync.value ?? [];

    final isLoadingConfig =
        memberId != null &&
        (memberSnapshot.connectionState == ConnectionState.waiting ||
            bemerkungSnapshot.connectionState == ConnectionState.waiting ||
            preisSnapshot.connectionState == ConnectionState.waiting ||
            leistungenAsync.isLoading);

    // ── Form Controllers ───────────────────────────────────────────────────
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
    final ctrlLeistung = useTextEditingController();
    final ctrlBeitrag = useTextEditingController();
    final ctrlVertragKontierung = useState<DateTime?>(null);
    final ctrlVertragLaufzeitVon = useState<DateTime?>(null);
    final ctrlVertragLaufzeitBis = useState<DateTime?>(null);

    // Bemerkung
    final ctrlBemerkungTitel = useTextEditingController();
    final ctrlBemerkungText = useTextEditingController();

    // ── Focus Nodes ────────────────────────────────────────────────────────
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
    final fnLeistung = useFocusNode();
    final fnBeitrag = useFocusNode();
    final fnVertragKontierung = useFocusNode();
    final fnVertragLaufzeitVon = useFocusNode();
    final fnVertragLaufzeitBis = useFocusNode();

    // ── Data Initialization ────────────────────────────────────────────────
    useEffect(
      () {
        if (memberSnapshot.hasData && memberSnapshot.data != null) {
          final m = memberSnapshot.data!;
          ctrlAnrede.text = m.anrede ?? '';
          ctrlName.text = m.name;
          ctrlVorname.text = m.vorname;
          ctrlGeboren.value = m.geboren;
          ctrlGeschlecht.text = m.geschlecht ?? '';

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

          if (m.leistungId != null) {
            final leistung = leistungen
                .where((l) => l.id == m.leistungId)
                .firstOrNull;
            if (leistung != null) {
              ctrlLeistung.text = leistung.name;
            }
          }
          if (preisSnapshot.hasData && preisSnapshot.data != null) {
            ctrlBeitrag.text = preisSnapshot.data!.bruttopreis.toStringAsFixed(
              2,
            );
          }
        }
        if (bemerkungSnapshot.hasData && bemerkungSnapshot.data != null) {
          final b = bemerkungSnapshot.data!;
          ctrlBemerkungTitel.text = b.titel;
          ctrlBemerkungText.text = b.textValue ?? '';
        }
        return null;
      },
      [
        memberSnapshot.data,
        bemerkungSnapshot.data,
        preisSnapshot.data,
        leistungen,
      ],
    );

    // ── Auto-fill Beitrag when Vertragsart changes ─────────────────────────
    // Whenever the Leistung field text changes AND a matching Leistung exists,
    // the Beitrag field is ALWAYS overwritten with that Leistung's DB price.
    useEffect(() {
      void onLeistungChanged() {
        final selected = leistungen
            .where((l) => l.name == ctrlLeistung.text)
            .firstOrNull;
        if (selected != null) {
          ctrlBeitrag.text = selected.bruttopreis.toStringAsFixed(2);
        }
      }

      ctrlLeistung.addListener(onLeistungChanged);
      return () => ctrlLeistung.removeListener(onLeistungChanged);
    }, [leistungen, ctrlBeitrag, ctrlLeistung]);

    // ── Auto Focus (contextual editing from grid double-click) ─────────────
    useEffect(() {
      if (!isLoadingConfig) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          switch (initialFocusField) {
            case 'name':
              fnName.requestFocus();
            case 'vorname':
              fnVorname.requestFocus();
            case 'ort':
              fnOrt.requestFocus();
            case 'telefon1':
              fnTelefon1.requestFocus();
            case 'email':
              fnEmail.requestFocus();
            case 'leistung_name':
              fnLeistung.requestFocus();
            case 'beitrag':
              fnBeitrag.requestFocus();
            case 'vertrag_laufzeit_von':
              fnVertragLaufzeitVon.requestFocus();
            case 'vertrag_laufzeit_bis':
              fnVertragLaufzeitBis.requestFocus();
            default:
              fnVorname.requestFocus(); // sensible default for new entries
          }
        });
      }
      return null;
    }, [isLoadingConfig]);

    final isSaving = useState(false);

    // ── Save Action ────────────────────────────────────────────────────────
    Future<void> saveMember() async {
      if (ctrlName.text.trim().isEmpty || ctrlVorname.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name und Vorname sind Pflichtfelder.')),
        );
        return;
      }

      isSaving.value = true;
      try {
        final repo = ref.read(membersRepositoryProvider);

        final companion = MitgliedsCompanion(
          id: memberId != null
              ? drift.Value(memberId!)
              : const drift.Value.absent(),
          anrede: drift.Value(ctrlAnrede.text.isEmpty ? null : ctrlAnrede.text),
          name: drift.Value(ctrlName.text.trim()),
          vorname: drift.Value(ctrlVorname.text.trim()),
          geboren: drift.Value(ctrlGeboren.value),
          geschlecht: drift.Value(
            ctrlGeschlecht.text.isEmpty ? null : ctrlGeschlecht.text,
          ),
          plz: drift.Value(ctrlPlz.text.isEmpty ? null : ctrlPlz.text),
          ort: drift.Value(ctrlOrt.text.isEmpty ? null : ctrlOrt.text),
          strasse: drift.Value(
            ctrlStrasse.text.isEmpty ? null : ctrlStrasse.text,
          ),
          hausnummer: drift.Value(
            ctrlHausnummer.text.isEmpty ? null : ctrlHausnummer.text,
          ),
          telefon1: drift.Value(
            ctrlTelefon1.text.isEmpty ? null : ctrlTelefon1.text,
          ),
          telefon2: drift.Value(
            ctrlTelefon2.text.isEmpty ? null : ctrlTelefon2.text,
          ),
          email: drift.Value(ctrlEmail.text.isEmpty ? null : ctrlEmail.text),
          vertragKontierung: drift.Value(ctrlVertragKontierung.value),
          vertragLaufzeitVon: drift.Value(ctrlVertragLaufzeitVon.value),
          vertragLaufzeitBis: drift.Value(ctrlVertragLaufzeitBis.value),
        );

        final selectedLeistung = leistungen
            .where((l) => l.name == ctrlLeistung.text)
            .firstOrNull;

        // ── Handle Preis ─────────────────────────────────────────────────
        final preiseRepo = ref.read(preiseRepositoryProvider);
        int? finalPreisId = memberSnapshot.data?.preisId;
        final inputBeitragStr = ctrlBeitrag.text.replaceAll(',', '.');
        final inputBeitrag = double.tryParse(inputBeitragStr);

        if (inputBeitrag != null) {
          if (finalPreisId != null) {
            final existingPreis = await preiseRepo.getPreisById(finalPreisId);
            if (existingPreis != null &&
                existingPreis.bruttopreis != inputBeitrag) {
              await preiseRepo.updatePreis(
                existingPreis.copyWith(bruttopreis: inputBeitrag),
              );
            }
          } else {
            finalPreisId = await preiseRepo.addPreis(
              PreisCompanion.insert(bruttopreis: inputBeitrag),
            );
          }
        } else if (ctrlBeitrag.text.trim().isEmpty && finalPreisId != null) {
          finalPreisId = null;
        }

        int savedMemberId;
        if (memberId == null) {
          savedMemberId = await repo.addMember(
            companion.copyWith(
              leistungId: drift.Value(selectedLeistung?.id),
              preisId: drift.Value(finalPreisId),
            ),
          );
        } else {
          await repo.updateMember(
            Mitglied(
              id: memberId!,
              name: companion.name.value,
              vorname: companion.vorname.value,
              anrede: companion.anrede.value,
              geboren: companion.geboren.value,
              geschlecht: companion.geschlecht.value,
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
              leistungId: selectedLeistung?.id,
              preisId: finalPreisId,
              bemerkungId: memberSnapshot.data?.bemerkungId,
            ),
          );
          savedMemberId = memberId!;
        }

        // Persist remark if title or text is non-empty
        final bemTitel = ctrlBemerkungTitel.text.trim();
        final bemText = ctrlBemerkungText.text.trim();
        if (bemTitel.isNotEmpty || bemText.isNotEmpty) {
          await repo.saveMemberRemark(
            savedMemberId,
            memberSnapshot.data?.bemerkungId,
            bemTitel.isNotEmpty ? bemTitel : 'Bemerkung',
            bemText,
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
      title: memberId == null ? 'Neues Mitglied' : 'Mitglied bearbeiten',
      isSaving: isSaving.value,
      onSave: saveMember,
      contentWidth: 800,
      deleteEntityLabel: 'Mitglied',
      exportConfig: memberId == null
          ? null
          : ExportConfig(
              item: memberSnapshot.data,
              entityType: 'mitglied',
              title: 'Mitglied ${ctrlName.text}',
            ),
      onDelete: memberId == null
          ? null
          : () async {
              await ref.read(membersRepositoryProvider).deleteMember(memberId!);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mitglied erfolgreich gelöscht'),
                  ),
                );
              }
            },
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Person ─────────────────────────────────────────────
          const AppSectionHeader('Person'),
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
              Expanded(
                child: AppTextField(
                  controller: ctrlVorname,
                  label: 'Vorname',
                  focusNode: fnVorname,
                  required: true,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextField(
                  controller: ctrlName,
                  label: 'Name',
                  focusNode: fnName,
                  required: true,
                ),
              ),
            ],
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: AppDatePickerField(
                  value: ctrlGeboren.value,
                  onChanged: (v) => ctrlGeboren.value = v,
                  label: 'Geburtsdatum',
                  focusNode: fnGeboren,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppDropdownField<String>(
                  controller: ctrlGeschlecht,
                  label: 'Geschlecht',
                  focusNode: fnGeschlecht,
                  options: const ['maennlich', 'weiblich', 'divers'],
                  getLabel: (v) => v,
                ),
              ),
            ],
          ),
          const Gap(24),

          // ── Kontakt ────────────────────────────────────────────
          const AppSectionHeader('Kontakt'),
          const Gap(8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AppTextField(
                  controller: ctrlStrasse,
                  label: 'Straße',
                  focusNode: fnStrasse,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextField(
                  controller: ctrlHausnummer,
                  label: 'Hausnummer',
                  focusNode: fnHausnummer,
                ),
              ),
            ],
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: ctrlPlz,
                  label: 'PLZ',
                  focusNode: fnPlz,
                  keyboardType: TextInputType.number,
                ),
              ),
              const Gap(8),
              Expanded(
                flex: 3,
                child: AppTextField(
                  controller: ctrlOrt,
                  label: 'Ort',
                  focusNode: fnOrt,
                ),
              ),
            ],
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: ctrlTelefon1,
                  label: 'Telefon 1',
                  focusNode: fnTelefon1,
                  keyboardType: TextInputType.phone,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextField(
                  controller: ctrlTelefon2,
                  label: 'Telefon 2',
                  focusNode: fnTelefon2,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const Gap(8),
          AppTextField(
            controller: ctrlEmail,
            label: 'E-Mail',
            focusNode: fnEmail,
            keyboardType: TextInputType.emailAddress,
          ),
          const Gap(24),

          // ── Vertrag ────────────────────────────────────────────
          const AppSectionHeader('Vertrag'),
          const Gap(8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppDropdownField<LeistungRowData>(
                  controller: ctrlLeistung,
                  label: 'Vertragsart',
                  focusNode: fnLeistung,
                  options: leistungen,
                  getLabel: (l) => l.name,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppTextField(
                  controller: ctrlBeitrag,
                  label: 'Beitrag (€)',
                  focusNode: fnBeitrag,
                ),
              ),
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
              Expanded(
                child: AppDatePickerField(
                  value: ctrlVertragLaufzeitVon.value,
                  onChanged: (v) => ctrlVertragLaufzeitVon.value = v,
                  label: 'Laufzeit von',
                  focusNode: fnVertragLaufzeitVon,
                ),
              ),
              const Gap(8),
              Expanded(
                child: AppDatePickerField(
                  value: ctrlVertragLaufzeitBis.value,
                  onChanged: (v) => ctrlVertragLaufzeitBis.value = v,
                  label: 'Laufzeit bis',
                  focusNode: fnVertragLaufzeitBis,
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
