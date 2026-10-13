import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common_widgets/forms/app_date_picker_field.dart';
import '../../../../common_widgets/forms/app_text_field.dart';
import '../../domain/models/zeitraum_typ.dart';
import '../providers/rechnungslegung_wizard_provider.dart';

/// Wizard-Schritt 3: Abrechnungszeitraum und Optionen.
class SchrittZeitraumOptionen extends HookConsumerWidget {
  const SchrittZeitraumOptionen({super.key});

  static const _monatsNamen = [
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rechnungslegungWizardProvider);
    final notifier = ref.read(rechnungslegungWizardProvider.notifier);
    final bemerkungController = useTextEditingController(
      text: state.bemerkung ?? '',
    );

    final jahre = useMemoized(
      () => List.generate(6, (i) => DateTime.now().year - i),
      [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Abrechnungszeitraum',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Gap(8),
        for (final typ in ZeitraumTyp.values)
          RadioListTile<ZeitraumTyp>(
            value: typ,
            groupValue: state.zeitraumTyp,
            onChanged: (t) {
              if (t != null) notifier.setZeitraumTyp(t);
            },
            title: Text(typ.label),
            dense: true,
          ),
        const Gap(8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (state.zeitraumTyp == ZeitraumTyp.monat) ...[
              _DropdownFeld<int>(
                label: 'Monat',
                value: state.monat,
                items: [
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem(
                      value: m,
                      child: Text(_monatsNamen[m - 1]),
                    ),
                ],
                onChanged: notifier.setMonat,
              ),
              _DropdownFeld<int>(
                label: 'Jahr',
                value: state.jahr,
                items: [
                  for (final j in jahre)
                    DropdownMenuItem(value: j, child: Text('$j')),
                ],
                onChanged: notifier.setJahr,
              ),
            ],
            if (state.zeitraumTyp == ZeitraumTyp.quartal) ...[
              _DropdownFeld<int>(
                label: 'Quartal',
                value: state.quartal,
                items: [
                  for (var q = 1; q <= 4; q++)
                    DropdownMenuItem(value: q, child: Text('Q$q')),
                ],
                onChanged: notifier.setQuartal,
              ),
              _DropdownFeld<int>(
                label: 'Jahr',
                value: state.jahr,
                items: [
                  for (final j in jahre)
                    DropdownMenuItem(value: j, child: Text('$j')),
                ],
                onChanged: notifier.setJahr,
              ),
            ],
            if (state.zeitraumTyp == ZeitraumTyp.jahr)
              _DropdownFeld<int>(
                label: 'Jahr',
                value: state.jahr,
                items: [
                  for (final j in jahre)
                    DropdownMenuItem(value: j, child: Text('$j')),
                ],
                onChanged: notifier.setJahr,
              ),
            if (state.zeitraumTyp == ZeitraumTyp.periode) ...[
              SizedBox(
                width: 200,
                child: AppDatePickerField(
                  value: state.von,
                  onChanged: (d) {
                    if (d != null) notifier.setVon(d);
                  },
                  label: 'Von',
                  required: true,
                ),
              ),
              SizedBox(
                width: 200,
                child: AppDatePickerField(
                  value: state.bis,
                  onChanged: (d) {
                    if (d != null) notifier.setBis(d);
                  },
                  label: 'Bis',
                  required: true,
                ),
              ),
            ],
          ],
        ),
        const Gap(16),
        Text('Optionen', style: Theme.of(context).textTheme.titleMedium),
        const Gap(8),
        CheckboxListTile(
          value: state.nurAktiveVertraege,
          onChanged: (v) => notifier.setNurAktiveVertraege(v ?? true),
          title: const Text('Nur aktive Verträge (Laufzeit bis >= heute)'),
          dense: true,
        ),
        CheckboxListTile(
          value: state.nurOhneOffene,
          onChanged: (v) => notifier.setNurOhneOffene(v ?? false),
          title: const Text('Nur Mitglieder ohne offene/kontierte Beiträge'),
          dense: true,
        ),
        const Gap(8),
        Row(
          children: [
            const Text('Status nach Erstellung:'),
            const Gap(16),
            _StatusRadio(
              value: 'kontiert',
              label: 'Kontiert',
              groupValue: state.zielStatus,
              onChanged: notifier.setZielStatus,
            ),
            _StatusRadio(
              value: 'offen',
              label: 'Offen',
              groupValue: state.zielStatus,
              onChanged: notifier.setZielStatus,
            ),
          ],
        ),
        const Gap(16),
        SizedBox(
          width: 400,
          child: AppTextField(
            controller: bemerkungController,
            label: 'Bemerkung (optional)',
            onChanged: notifier.setBemerkung,
          ),
        ),
      ],
    );
  }
}

/// Generisches Dropdown mit Label und Rahmen (Desktop-Stil).
class _DropdownFeld<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  const _DropdownFeld({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: items,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Radio-Button für den Zielstatus mit Statusfarbe.
class _StatusRadio extends StatelessWidget {
  final String value;
  final String label;
  final String groupValue;
  final ValueChanged<String> onChanged;

  const _StatusRadio({
    required this.value,
    required this.label,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          groupValue: groupValue,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
        Text(label),
        const Gap(8),
      ],
    );
  }
}
