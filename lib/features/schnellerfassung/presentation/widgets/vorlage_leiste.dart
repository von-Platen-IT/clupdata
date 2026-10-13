import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common_widgets/forms/app_text_field.dart';
import '../../data/vorlage_repository.dart';
import '../../domain/models/schnellerfassung_felder.dart';
import '../../domain/models/vorlage.dart';
import '../providers/schnellerfassung_providers.dart';
import 'mitglied_vorlage_dialog.dart';

/// Vorlagen-Leiste der Schnellerfassung.
///
/// Drei Vorlagen-Mechanismen (siehe `plans/schnellerfassung.md`):
/// 1. Benannte Vorlagen laden/speichern/löschen
/// 2. Von vorhandenem Datensatz übernehmen
/// 3. Auto-Vorlage („Speichern & Felder behalten") – im Screen
class VorlageLeiste extends ConsumerWidget {
  /// Aktuelle Formularfelder (für „Als Vorlage speichern").
  final SchnellerfassungFelder aktuelleFelder;

  /// Wird aufgerufen, wenn Felder übernommen werden sollen (Vorlage/Datensatz).
  final ValueChanged<SchnellerfassungFelder> onFelderUebernehmen;

  const VorlageLeiste({
    super.key,
    required this.aktuelleFelder,
    required this.onFelderUebernehmen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vorlagenAsync = ref.watch(vorlagenListeProvider);

    return Row(
      children: [
        const Text('Vorlage:'),
        const Gap(8),
        vorlagenAsync.when(
          data: (vorlagen) => DropdownButton<Vorlage?>(
            hint: const Text('Keine'),
            value: null,
            items: [
              const DropdownMenuItem<Vorlage?>(
                value: null,
                child: Text('Keine Vorlage'),
              ),
              for (final v in vorlagen)
                DropdownMenuItem<Vorlage?>(value: v, child: Text(v.name)),
            ],
            onChanged: (v) {
              if (v != null) {
                onFelderUebernehmen(SchnellerfassungFelder.fromMap(v.felder));
              }
            },
          ),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => Text('Fehler: $e'),
        ),
        const Gap(8),
        OutlinedButton.icon(
          onPressed: () => _zeigeSpeichernDialog(context, ref),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Als Vorlage speichern…'),
        ),
        const Gap(8),
        OutlinedButton.icon(
          onPressed: () => _uebernehmeVonDatensatz(context, ref),
          icon: const Icon(Icons.person_search),
          label: const Text('Von vorhandenem Datensatz…'),
        ),
      ],
    );
  }

  Future<void> _zeigeSpeichernDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Als Vorlage speichern'),
        content: SizedBox(
          width: 360,
          child: AppTextField(
            controller: nameController,
            label: 'Name der Vorlage',
            required: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(nameController.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;

    final repo = ref.read(vorlageRepositoryProvider);
    await repo.saveVorlage(name, aktuelleFelder);
    ref.invalidate(vorlagenListeProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Vorlage „$name" gespeichert.')));
    }
  }

  Future<void> _uebernehmeVonDatensatz(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final mitglied = await MitgliedVorlageDialog.show(context);
    if (mitglied == null) return;

    // Personenfelder werden geleert – Name bleibt (Familien-Erfassung).
    onFelderUebernehmen(
      SchnellerfassungFelder(
        anrede: mitglied.anrede ?? '',
        geschlecht: mitglied.geschlecht ?? '',
        name: mitglied.name,
        vorname: '',
        geboren: mitglied.geboren,
        plz: mitglied.plz ?? '',
        ort: mitglied.ort ?? '',
        strasse: mitglied.strasse ?? '',
        hausnummer: mitglied.hausnummer ?? '',
        telefon: mitglied.telefon1 ?? '',
        email: mitglied.email ?? '',
        leistungId: mitglied.leistungId,
        vertragVon: mitglied.vertragLaufzeitVon,
      ),
    );
  }
}
