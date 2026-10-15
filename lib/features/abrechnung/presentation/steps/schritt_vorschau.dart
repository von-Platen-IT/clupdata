import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/models/vorschau_zeile.dart';
import '../providers/abrechnungslauf_provider.dart';

/// Schritt 2 des Abrechnungslaufs: editierbare Vorschau (Kernstück).
///
/// Jede Zeile ist per Checkbox auswählbar, der Betrag ist überschreibbar.
/// Bereits abgerechnete Perioden sind markiert und abgewählt.
class SchrittVorschau extends HookConsumerWidget {
  const SchrittVorschau({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(abrechnungslaufProvider);
    final notifier = ref.read(abrechnungslaufProvider.notifier);
    final dateFormat = DateFormat('MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _KennzahlenLeiste(
          zuErstellen: state.zuErstellenAnzahl,
          bereitsAbgerechnet: state.bereitsAbgerechnetAnzahl,
          summe: state.zuErstellenBetrag,
        ),
        const Gap(12),
        Row(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.select_all, size: 18),
              label: const Text('Alle auswählen'),
              onPressed: () => notifier.setzeAlleAuswahl(true),
            ),
            TextButton.icon(
              icon: const Icon(Icons.deselect, size: 18),
              label: const Text('Alle abwählen'),
              onPressed: () => notifier.setzeAlleAuswahl(false),
            ),
          ],
        ),
        const Gap(8),
        SizedBox(
          height: 360,
          child: state.vorschauZeilen.isEmpty
              ? const Center(child: Text('Keine Zeilen gefunden.'))
              : ListView.builder(
                  itemCount: state.vorschauZeilen.length,
                  itemBuilder: (context, index) => _VorschauZeileTile(
                    index: index,
                    zeile: state.vorschauZeilen[index],
                    dateFormat: dateFormat,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Zusammenfassungs-Leiste über der Vorschau-Tabelle.
class _KennzahlenLeiste extends StatelessWidget {
  const _KennzahlenLeiste({
    required this.zuErstellen,
    required this.bereitsAbgerechnet,
    required this.summe,
  });

  final int zuErstellen;
  final int bereitsAbgerechnet;
  final double summe;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Kennzahl(icon: Icons.check_circle, label: 'Erstellen', wert: '$zuErstellen'),
        _Kennzahl(icon: Icons.history, label: 'Bereits abgerechnet', wert: '$bereitsAbgerechnet'),
        _Kennzahl(
          icon: Icons.euro,
          label: 'Summe',
          wert: formatCurrencyEur(summe),
        ),
      ],
    );
  }
}

/// Einzelne Kennzahl in der Zusammenfassung.
class _Kennzahl extends StatelessWidget {
  const _Kennzahl({required this.icon, required this.label, required this.wert});

  final IconData icon;
  final String label;
  final String wert;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const Gap(6),
          Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
          Text(wert, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Eine editierbare Vorschauzeile (Checkbox + Betrag + Hinweis).
class _VorschauZeileTile extends ConsumerWidget {
  const _VorschauZeileTile({
    required this.index,
    required this.zeile,
    required this.dateFormat,
  });

  final int index;
  final VorschauZeile zeile;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(abrechnungslaufProvider.notifier);
    final abgeschaltet = zeile.bereitsAbgerechnet;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: abgeschaltet ? Theme.of(context).colorScheme.surfaceContainerHighest : null,
      child: ListTile(
        dense: true,
        leading: Checkbox(
          value: zeile.inkludiert && !abgeschaltet,
          onChanged: abgeschaltet
              ? null
              : (v) => notifier.aktualisiereZeile(
                  index,
                  zeile.copyWith(inkludiert: v ?? false),
                ),
        ),
        title: Text(zeile.mitgliedName),
        subtitle: Text(
          '${zeile.leistungName} · ${dateFormat.format(zeile.abrechnungsZeitraum)}'
          '${zeile.hinweis != null ? ' · ${zeile.hinweis}' : ''}',
        ),
        trailing: SizedBox(
          width: 140,
          child: TextFormField(
            key: ValueKey('betrag_$index'),
            initialValue: zeile.betrag.toStringAsFixed(2),
            enabled: !abgeschaltet,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              suffixText: '€',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onFieldSubmitted: (v) {
              final betrag = double.tryParse(v.replaceAll(',', '.')) ?? zeile.betrag;
              notifier.aktualisiereZeile(index, zeile.copyWith(betrag: betrag));
            },
          ),
        ),
      ),
    );
  }
}
