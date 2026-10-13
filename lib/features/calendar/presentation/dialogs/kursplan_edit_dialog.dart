import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../../common_widgets/forms/app_date_picker_field.dart';
import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../core/database/database.dart';
import '../../data/kursplan_repository.dart';
import '../../domain/models/kursplan_row_data.dart';
import '../../domain/wochen_utils.dart';
import '../providers/kursplan_providers.dart';
import 'kursplan_termin_editor.dart';

/// Dialog zum Anlegen/Bearbeiten eines Kursplans inklusive Terminen.
///
/// `gueltigVon`/`gueltigBis` werden auf Montage normalisiert.
class KursplanEditDialog extends HookConsumerWidget {
  /// Bestehender Plan; `null` = neuer Plan.
  final KursplanRowData? plan;

  const KursplanEditDialog({super.key, this.plan});

  /// Opens the dialog. Pass [plan] to edit, omit it to create.
  static Future<void> show(BuildContext context, {KursplanRowData? plan}) {
    return showDialog(
      context: context,
      builder: (_) => KursplanEditDialog(plan: plan),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController(text: plan?.name ?? '');
    final gueltigVon = useState<DateTime>(
      plan?.gueltigVon ?? montagVon(DateTime.now()),
    );
    final gueltigBis = useState<DateTime?>(plan?.gueltigBis);
    final termine = useState<List<TerminEingabe>>([]);
    final geladen = useState(false);
    final isSaving = useState(false);
    final errorText = useState<String?>(null);

    final kurseAsync = ref.watch(kurseListProvider);

    // Bestehende Termine beim Öffnen laden.
    useEffect(() {
      if (plan != null && !geladen.value) {
        geladen.value = true;
        final repo = ref.read(kursplanRepositoryProvider);
        repo.loadTermine(plan!.id).then((vorhandene) {
          termine.value = [
            for (final t in vorhandene)
              TerminEingabe(
                kursId: t.kursId,
                wochentag: t.wochentag,
                startzeit: t.startzeit,
                endezeit: t.endezeit,
              ),
          ];
        });
      }
      return null;
    }, []);

    Future<void> speichern() async {
      final name = nameController.text.trim();
      if (name.isEmpty) {
        errorText.value = 'Name ist ein Pflichtfeld.';
        return;
      }
      if (gueltigBis.value != null &&
          gueltigBis.value!.isBefore(gueltigVon.value)) {
        errorText.value = '„Gültig bis" liegt vor „Gültig von".';
        return;
      }

      // Termine validieren und in Companions überführen.
      final companions = <KursplanTermineCompanion>[];
      for (final t in termine.value) {
        if (t.kursId == null) {
          errorText.value = 'Jeder Termin braucht einen Kurs.';
          return;
        }
        final start = parseZeit(t.startzeit);
        if (start == null) {
          errorText.value =
              'Ungültige Startzeit (Format HH:mm): ${t.startzeit}';
          return;
        }
        if (t.endezeit != null) {
          final ende = parseZeit(t.endezeit!);
          if (ende == null) {
            errorText.value = 'Ungültige Endzeit (Format HH:mm): ${t.endezeit}';
            return;
          }
          if (ende <= start) {
            errorText.value =
                'Endzeit muss nach der Startzeit liegen (${t.startzeit}–${t.endezeit}).';
            return;
          }
        }
        companions.add(
          KursplanTermineCompanion.insert(
            kursplanId: 0, // wird in saveKursplan durch die echte ID ersetzt
            kursId: t.kursId!,
            wochentag: t.wochentag,
            startzeit: t.startzeit,
            endezeit: drift.Value(t.endezeit),
          ),
        );
      }

      isSaving.value = true;
      try {
        final repo = ref.read(kursplanRepositoryProvider);
        await repo.saveKursplan(
          bestehend: plan,
          name: name,
          gueltigVon: gueltigVon.value,
          gueltigBis: gueltigBis.value,
          termine: companions,
        );
        if (context.mounted) Navigator.of(context).pop();
      } finally {
        isSaving.value = false;
      }
    }

    return AppEditDialogScaffold(
      title: plan == null ? 'Neuer Kursplan' : 'Kursplan bearbeiten',
      contentWidth: 720,
      isSaving: isSaving.value,
      onSave: speichern,
      content: kurseAsync.when(
        data: (kurse) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errorText.value != null) ...[
              Text(
                errorText.value!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const Gap(8),
            ],
            AppTextField(
              controller: nameController,
              label: 'Name',
              required: true,
            ),
            const Gap(12),
            Row(
              children: [
                SizedBox(
                  width: 200,
                  child: AppDatePickerField(
                    value: gueltigVon.value,
                    onChanged: (d) {
                      if (d != null) gueltigVon.value = d;
                    },
                    label: 'Gültig von',
                    required: true,
                  ),
                ),
                const Gap(16),
                SizedBox(
                  width: 200,
                  child: AppDatePickerField(
                    value: gueltigBis.value,
                    onChanged: (d) => gueltigBis.value = d,
                    label: 'Gültig bis (optional)',
                  ),
                ),
              ],
            ),
            const Gap(8),
            Text(
              'Die Gültigkeit wird auf Wochenanfänge (Montage) normalisiert. '
              'Ohne „Gültig bis" gilt der Plan unbegrenzt.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Gap(16),
            KursplanTerminEditor(
              termine: termine.value,
              kurse: kurse,
              onChanged: (liste) => termine.value = [...liste],
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Fehler beim Laden der Kurse: $e'),
      ),
    );
  }
}
