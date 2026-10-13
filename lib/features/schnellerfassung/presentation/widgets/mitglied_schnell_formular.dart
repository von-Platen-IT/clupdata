import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common_widgets/forms/app_date_picker_field.dart';
import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../leistungen/presentation/providers/leistungen_list_provider.dart';
import '../../domain/models/schnellerfassung_felder.dart';

/// Eingabeformular der Mitglieder-Schnellerfassung.
///
/// Controlled Component: Die Felder werden über [initial] vorbelegt und bei
/// jeder Änderung über [onChanged] gemeldet. Ein Wechsel von [initial]
/// (z. B. Vorlage laden) erfordert einen neuen Widget-[Key], damit die
/// Text-Controller neu initialisiert werden.
class MitgliedSchnellFormular extends HookConsumerWidget {
  final SchnellerfassungFelder initial;
  final ValueChanged<SchnellerfassungFelder> onChanged;

  const MitgliedSchnellFormular({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final felder = useState(initial);
    final leistungenAsync = ref.watch(watchLeistungenDetailsProvider);

    final nameController = useTextEditingController(text: initial.name);
    final vornameController = useTextEditingController(text: initial.vorname);
    final plzController = useTextEditingController(text: initial.plz);
    final ortController = useTextEditingController(text: initial.ort);
    final strasseController = useTextEditingController(text: initial.strasse);
    final hausnummerController = useTextEditingController(
      text: initial.hausnummer,
    );
    final telefonController = useTextEditingController(text: initial.telefon);
    final emailController = useTextEditingController(text: initial.email);
    final bemerkungController = useTextEditingController(
      text: initial.bemerkung,
    );

    void aktualisiere(
      SchnellerfassungFelder Function(SchnellerfassungFelder) f,
    ) {
      felder.value = f(felder.value);
      onChanged(felder.value);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Person', style: Theme.of(context).textTheme.titleMedium),
        const Gap(8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 140,
              child: DropdownButtonFormField<String>(
                value: initial.anrede.isEmpty ? null : initial.anrede,
                decoration: const InputDecoration(
                  labelText: 'Anrede',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Herr', child: Text('Herr')),
                  DropdownMenuItem(value: 'Frau', child: Text('Frau')),
                  DropdownMenuItem(value: 'Divers', child: Text('Divers')),
                  DropdownMenuItem(value: 'Keine', child: Text('Keine')),
                ],
                onChanged: (v) =>
                    aktualisiere((f) => f.copyWith(anrede: v ?? '')),
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                value: initial.geschlecht.isEmpty ? null : initial.geschlecht,
                decoration: const InputDecoration(
                  labelText: 'Geschlecht',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'maennlich', child: Text('männlich')),
                  DropdownMenuItem(value: 'weiblich', child: Text('weiblich')),
                  DropdownMenuItem(value: 'divers', child: Text('divers')),
                ],
                onChanged: (v) =>
                    aktualisiere((f) => f.copyWith(geschlecht: v ?? '')),
              ),
            ),
          ],
        ),
        const Gap(12),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: nameController,
                label: 'Name',
                required: true,
                onChanged: (t) => aktualisiere((f) => f.copyWith(name: t)),
              ),
            ),
            const Gap(12),
            Expanded(
              child: AppTextField(
                controller: vornameController,
                label: 'Vorname',
                required: true,
                onChanged: (t) => aktualisiere((f) => f.copyWith(vorname: t)),
              ),
            ),
            const Gap(12),
            SizedBox(
              width: 180,
              child: AppDatePickerField(
                value: initial.geboren,
                onChanged: (d) => aktualisiere((f) => f.copyWith(geboren: d)),
                label: 'Geboren',
              ),
            ),
          ],
        ),
        const Gap(16),
        Text('Kontakt', style: Theme.of(context).textTheme.titleMedium),
        const Gap(8),
        Row(
          children: [
            SizedBox(
              width: 100,
              child: AppTextField(
                controller: plzController,
                label: 'PLZ',
                onChanged: (t) => aktualisiere((f) => f.copyWith(plz: t)),
              ),
            ),
            const Gap(12),
            Expanded(
              child: AppTextField(
                controller: ortController,
                label: 'Ort',
                onChanged: (t) => aktualisiere((f) => f.copyWith(ort: t)),
              ),
            ),
          ],
        ),
        const Gap(12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: AppTextField(
                controller: strasseController,
                label: 'Strasse',
                onChanged: (t) => aktualisiere((f) => f.copyWith(strasse: t)),
              ),
            ),
            const Gap(12),
            SizedBox(
              width: 100,
              child: AppTextField(
                controller: hausnummerController,
                label: 'Nr.',
                onChanged: (t) =>
                    aktualisiere((f) => f.copyWith(hausnummer: t)),
              ),
            ),
            const Gap(12),
            Expanded(
              flex: 2,
              child: AppTextField(
                controller: telefonController,
                label: 'Telefon',
                onChanged: (t) => aktualisiere((f) => f.copyWith(telefon: t)),
              ),
            ),
            const Gap(12),
            Expanded(
              flex: 3,
              child: AppTextField(
                controller: emailController,
                label: 'E-Mail',
                onChanged: (t) => aktualisiere((f) => f.copyWith(email: t)),
              ),
            ),
          ],
        ),
        const Gap(16),
        Text('Vertrag', style: Theme.of(context).textTheme.titleMedium),
        const Gap(8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: leistungenAsync.when(
                data: (leistungen) => DropdownButtonFormField<int>(
                  value: initial.leistungId,
                  decoration: const InputDecoration(
                    labelText: 'Leistung *',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final l in leistungen)
                      DropdownMenuItem(
                        value: l.leistung.id,
                        child: Text(l.leistung.name),
                      ),
                  ],
                  onChanged: (v) =>
                      aktualisiere((f) => f.copyWith(leistungId: v)),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Fehler: $e'),
              ),
            ),
            SizedBox(
              width: 200,
              child: AppDatePickerField(
                value: initial.vertragVon,
                onChanged: (d) =>
                    aktualisiere((f) => f.copyWith(vertragVon: d)),
                label: 'Vertrag beginnt am',
              ),
            ),
          ],
        ),
        const Gap(16),
        Text('Bemerkung', style: Theme.of(context).textTheme.titleMedium),
        const Gap(8),
        SizedBox(
          width: 420,
          child: AppTextField(
            controller: bemerkungController,
            label: 'Bemerkung (optional)',
            onChanged: (t) => aktualisiere((f) => f.copyWith(bemerkung: t)),
          ),
        ),
      ],
    );
  }
}
