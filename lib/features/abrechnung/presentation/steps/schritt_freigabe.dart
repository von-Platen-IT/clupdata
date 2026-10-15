import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/datum_utils.dart';
import '../providers/abrechnungslauf_provider.dart';

/// Schritt 3 des Abrechnungslaufs: Freigabe mit Optionen.
///
/// Zusammenfassung, Zielstatus, Zahlungsziel und Pflicht-Bemerkung.
class SchrittFreigabe extends HookConsumerWidget {
  const SchrittFreigabe({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(abrechnungslaufProvider);
    final notifier = ref.read(abrechnungslaufProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  '${state.zuErstellenAnzahl} Beiträge · '
                  '${formatCurrencyEur(state.zuErstellenBetrag)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  'Fällig: ${DateFormat('dd.MM.yyyy').format(addiereTage(DateTime.now(), state.zahlungszielTage))}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const Gap(16),
        Text(
          'Status nach Erstellung',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const Gap(4),
        RadioListTile<String>(
          title: const Text('Offen (zahlbar)'),
          subtitle: const Text(
            'Fälligkeit aktiv, direkt in der offenen Posten-Liste',
          ),
          value: 'offen',
          groupValue: state.zielStatus,
          onChanged: (v) => notifier.setzeOptionen(zielStatus: v),
        ),
        RadioListTile<String>(
          title: const Text('Entwurf/Kontiert (noch nicht versendet)'),
          subtitle: const Text('Kann vor dem Versand weiter bearbeitet werden'),
          value: 'kontiert',
          groupValue: state.zielStatus,
          onChanged: (v) => notifier.setzeOptionen(zielStatus: v),
        ),
        const Gap(12),
        Row(
          children: [
            const Text('Zahlungsziel:'),
            const Gap(12),
            for (final tage in [7, 14, 30])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$tage Tage'),
                  selected: state.zahlungszielTage == tage,
                  onSelected: (_) =>
                      notifier.setzeOptionen(zahlungszielTage: tage),
                ),
              ),
          ],
        ),
        const Gap(12),
        SwitchListTile(
          title: const Text('Nur aktive Verträge'),
          subtitle: const Text('Vertragslaufzeit bis mindestens heute'),
          value: state.nurAktiveVertraege,
          onChanged: (v) => notifier.setzeOptionen(nurAktiveVertraege: v),
        ),
        SwitchListTile(
          title: const Text('Nur Mitglieder ohne offene/kontierte Beiträge'),
          value: state.nurOhneOffene,
          onChanged: (v) => notifier.setzeOptionen(nurOhneOffene: v),
        ),
        const Gap(12),
        AppTextField(
          controller: useTextEditingController(text: state.bemerkung ?? ''),
          label: 'Bemerkung (Pflicht für Status-Verlauf)',
          maxLines: 2,
          onChanged: (v) => notifier.setzeOptionen(bemerkung: v),
        ),
      ],
    );
  }
}
