import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/models/vorschau_zeile.dart';
import '../providers/rechnungslegung_wizard_provider.dart';
import 'betrag_edit_dialog.dart';

/// Wizard-Schritt 4: Editierbare Vorschau aller zu erstellenden Beiträge.
///
/// Zeilen können abgewählt, Beträge überschrieben werden. Bereits
/// abgerechnete Perioden sind markiert und per Standard abgewählt.
class SchrittVorschau extends ConsumerWidget {
  const SchrittVorschau({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rechnungslegungWizardProvider);
    final zeilen = state.vorschauZeilen;
    final bereitsCount = zeilen.where((z) => z.bereitsAbgerechnet).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          children: [
            Text('Zu erstellen: ${state.zuErstellenAnzahl}'),
            Text('Bereits abgerechnet: $bereitsCount'),
            Text('Gesamt: ${formatCurrencyEur(state.zuErstellenBetrag)}'),
          ],
        ),
        const Gap(8),
        const _TabellenKopf(),
        const Divider(height: 1),
        for (var i = 0; i < zeilen.length; i++)
          _VorschauZeileWidget(zeile: zeilen[i], index: i),
        if (zeilen.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Keine passenden Mitglieder/Perioden gefunden.'),
          ),
      ],
    );
  }
}

/// Spaltenüberschrift der Vorschau-Tabelle.
class _TabellenKopf extends StatelessWidget {
  const _TabellenKopf();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Row(
      children: [
        const SizedBox(width: 40),
        Expanded(flex: 3, child: Text('Mitglied', style: style)),
        Expanded(flex: 2, child: Text('Kurs/Leistung', style: style)),
        SizedBox(width: 80, child: Text('Zeitraum', style: style)),
        SizedBox(width: 100, child: Text('Betrag', style: style)),
        Expanded(flex: 2, child: Text('Hinweis', style: style)),
      ],
    );
  }
}

/// Eine editierbare Vorschauzeile (Checkbox, Betrag-Edit, Hinweis).
class _VorschauZeileWidget extends ConsumerWidget {
  final VorschauZeile zeile;
  final int index;

  const _VorschauZeileWidget({required this.zeile, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(rechnungslegungWizardProvider.notifier);
    final periode =
        '${zeile.abrechnungsZeitraum.month.toString().padLeft(2, '0')}.'
        '${zeile.abrechnungsZeitraum.year}';
    final betragText = formatCurrencyEur(zeile.betrag);

    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Checkbox(
            value: zeile.inkludiert,
            onChanged: (_) => notifier.toggleZeile(index),
          ),
        ),
        Expanded(flex: 3, child: Text(zeile.mitgliedName)),
        Expanded(flex: 2, child: Text(zeile.leistungName)),
        SizedBox(width: 80, child: Text(periode)),
        SizedBox(
          width: 100,
          child: TextButton(
            onPressed: () => BetragEditDialog.show(
              context,
              index: index,
              initialBetrag: zeile.betrag,
            ),
            child: Text(betragText, textAlign: TextAlign.end),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            zeile.hinweis ?? '',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
