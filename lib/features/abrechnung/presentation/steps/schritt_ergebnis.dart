import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../providers/abrechnungslauf_provider.dart';

/// Schritt 4 des Abrechnungslaufs: Ergebnis & Anschlussaktionen.
class SchrittErgebnis extends HookConsumerWidget {
  const SchrittErgebnis({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(abrechnungslaufProvider);
    final erfolgreich = state.fehler.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              erfolgreich ? Icons.check_circle : Icons.warning,
              size: 40,
              color: erfolgreich ? Colors.green : Colors.orange,
            ),
            const Gap(12),
            Text(
              erfolgreich
                  ? '${state.erstelltAnzahl} Beiträge erfolgreich erstellt'
                  : '${state.erstelltAnzahl} erstellt, ${state.fehler.length} Fehler',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        const Gap(16),
        _ErgebnisZeile(label: 'Erstellt', wert: '${state.erstelltAnzahl}'),
        _ErgebnisZeile(label: 'Übersprungen', wert: '${state.uebersprungenAnzahl}'),
        _ErgebnisZeile(label: 'Fehler', wert: '${state.fehler.length}'),
        _ErgebnisZeile(
          label: 'Gesamtbetrag',
          wert: formatCurrencyEur(state.gesamtBetrag),
        ),
        if (state.fehler.isNotEmpty) ...[
          const Gap(12),
          Text('Fehlerdetails:', style: Theme.of(context).textTheme.titleSmall),
          for (final f in state.fehler.take(5))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $f', style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
        const Gap(20),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.list),
              label: const Text('Beiträge anzeigen'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF-Sammeldruck'),
              onPressed: state.erstelltAnzahl == 0
                  ? null
                  : () {
                      // TODO(architekt): PDF-Sammeldruck über Export-Feature.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('PDF-Sammeldruck folgt in Phase 6.'),
                        ),
                      );
                    },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.table_chart),
              label: const Text('CSV'),
              onPressed: state.erstelltAnzahl == 0
                  ? null
                  : () {
                      // TODO(architekt): CSV-Export über data_grid_v2/export.
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('CSV-Export folgt in Phase 6.'),
                        ),
                      );
                    },
            ),
          ],
        ),
      ],
    );
  }
}

/// Beschriftete Ergebniszeile.
class _ErgebnisZeile extends StatelessWidget {
  const _ErgebnisZeile({required this.label, required this.wert});

  final String label;
  final String wert;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(label)),
          Text(wert, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
