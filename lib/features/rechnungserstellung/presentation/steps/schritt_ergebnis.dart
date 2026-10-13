import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../providers/rechnungslegung_wizard_provider.dart';

/// Wizard-Schritt 5: Ergebnis der Beitrags-Erstellung.
class SchrittErgebnis extends ConsumerWidget {
  const SchrittErgebnis({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rechnungslegungWizardProvider);

    return Column(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 48),
        const Gap(8),
        Text(
          '${state.erstelltAnzahl} Beiträge erfolgreich erstellt',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Gap(16),
        _ErgebnisZeile('Erstellt:', '${state.erstelltAnzahl}'),
        _ErgebnisZeile(
          'Übersprungen:',
          '${state.uebersprungenAnzahl} (bereits abgerechnet)',
        ),
        _ErgebnisZeile('Gesamtbetrag:', formatCurrencyEur(state.gesamtBetrag)),
        const Gap(16),
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            context.go('/beitraege');
          },
          icon: const Icon(Icons.list),
          label: const Text('Beiträge anzeigen'),
        ),
      ],
    );
  }
}

/// Beschriftetes Ergebnis-Kennzahl-Paar.
class _ErgebnisZeile extends StatelessWidget {
  final String label;
  final String wert;

  const _ErgebnisZeile(this.label, this.wert);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 140, child: Text(label)),
          Text(wert, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
