import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/models/empfaenger_kreis.dart';
import '../../domain/models/zeitraum_typ.dart';
import '../providers/abrechnungslauf_provider.dart';

/// Schritt 1 des Abrechnungslaufs: Empfängerkreis + Zeitraum.
///
/// Standardfall „Alle Mitglieder, laufender Monat" ist vorausgewählt –
/// ein Klick auf „Vorschau berechnen" genügt (2-Klick-Workflow).
class SchrittLauf extends HookConsumerWidget {
  const SchrittLauf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(abrechnungslaufProvider);
    final notifier = ref.read(abrechnungslaufProvider.notifier);
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Empfängerkreis',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const Gap(8),
        Wrap(
          spacing: 8,
          children: [
            for (final kreis in EmpfaengerKreis.values)
              ChoiceChip(
                label: Text(kreis.label),
                selected: state.kreis == kreis,
                onSelected: (_) => notifier.setzeKreis(kreis),
              ),
          ],
        ),
        const Gap(4),
        Text(
          state.kreis.description,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (state.kreis == EmpfaengerKreis.mitglieder ||
            state.kreis == EmpfaengerKreis.einzelnesMitglied ||
            state.kreis == EmpfaengerKreis.kurse)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: _AuswahlHinweis(),
          ),
        const Gap(24),
        Text(
          'Abrechnungszeitraum',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const Gap(8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final typ in ZeitraumTyp.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<ZeitraumTyp>(
                    value: typ,
                    groupValue: state.zeitraumTyp,
                    onChanged: (t) => notifier.setzeZeitraum(zeitraumTyp: t),
                  ),
                  Text(typ.label),
                ],
              ),
          ],
        ),
        const Gap(8),
        _ZeitraumAuswahl(state: state, notifier: notifier, now: now),
        const Gap(12),
        Text(
          'Der Vertragsrhythmus erzeugt automatisch die passenden Perioden '
          '(z. B. 3 Beiträge bei quartalsweiser Laufzeit im Quartal).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Zeigt den modusabhängigen Auswähler für Monat/Quartal/Jahr/Periode.
class _ZeitraumAuswahl extends StatelessWidget {
  const _ZeitraumAuswahl({
    required this.state,
    required this.notifier,
    required this.now,
  });

  final dynamic state;
  final dynamic notifier;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final monatFormat = DateFormat('MMMM yyyy', 'de_DE');
    switch (state.zeitraumTyp as ZeitraumTyp) {
      case ZeitraumTyp.monat:
        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                final d = DateTime(state.jahr, state.monat - 1, 1);
                notifier.setzeZeitraum(jahr: d.year, monat: d.month);
              },
            ),
            Text(monatFormat.format(DateTime(state.jahr, state.monat))),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final d = DateTime(state.jahr, state.monat + 1, 1);
                notifier.setzeZeitraum(jahr: d.year, monat: d.month);
              },
            ),
          ],
        );
      case ZeitraumTyp.quartal:
        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                final q = state.quartal - 1;
                notifier.setzeZeitraum(
                  jahr: q < 1 ? state.jahr - 1 : state.jahr,
                  quartal: q < 1 ? 4 : q,
                );
              },
            ),
            Text('Q${state.quartal} ${state.jahr}'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                final q = state.quartal + 1;
                notifier.setzeZeitraum(
                  jahr: q > 4 ? state.jahr + 1 : state.jahr,
                  quartal: q > 4 ? 1 : q,
                );
              },
            ),
          ],
        );
      case ZeitraumTyp.jahr:
        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => notifier.setzeZeitraum(jahr: state.jahr - 1),
            ),
            Text('${state.jahr}'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => notifier.setzeZeitraum(jahr: state.jahr + 1),
            ),
          ],
        );
      case ZeitraumTyp.periode:
        return Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                state.von == null
                    ? 'von'
                    : DateFormat('dd.MM.yyyy').format(state.von!),
              ),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: state.von ?? now,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) notifier.setzeZeitraum(von: d);
              },
            ),
            const Gap(8),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                state.bis == null
                    ? 'bis'
                    : DateFormat('dd.MM.yyyy').format(state.bis!),
              ),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: state.bis ?? now,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) notifier.setzeZeitraum(bis: d);
              },
            ),
          ],
        );
    }
  }
}

/// Hinweis, wenn der Empfängerkreis eine Zusatzauswahl benötigt.
class _AuswahlHinweis extends StatelessWidget {
  const _AuswahlHinweis();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Die konkrete Auswahl erfolgt im nächsten Schritt über die Vorschau '
      'bzw. in der Kurs-/Mitgliederansicht.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
