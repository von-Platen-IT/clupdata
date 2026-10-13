import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../leistungen/presentation/providers/leistungen_list_provider.dart';
import '../providers/rechnungslegung_wizard_provider.dart';

/// Wizard-Schritt 2 (Modus „Kurse"): Auswahl von Leistungen/Kursen.
///
/// Kurse entsprechen `leistung`-Datensätzen (Vertragsarten) – siehe ADR-001.
class KursAuswahl extends ConsumerWidget {
  const KursAuswahl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rechnungslegungWizardProvider);
    final notifier = ref.read(rechnungslegungWizardProvider.notifier);
    final leistungenAsync = ref.watch(watchLeistungenDetailsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ausgewählte Kurse: ${state.leistungIds.length}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Gap(8),
        leistungenAsync.when(
          data: (leistungen) => Column(
            children: [
              for (final l in leistungen)
                CheckboxListTile(
                  value: state.leistungIds.contains(l.leistung.id),
                  onChanged: (_) => notifier.toggleLeistung(l.leistung.id),
                  title: Text(l.leistung.name),
                  subtitle: Text(
                    '${_laufzeitLabel(l.leistung.laufzeit)} · '
                    '${formatCurrencyEur(l.preis.bruttopreis)}',
                  ),
                  dense: true,
                ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Fehler beim Laden der Kurse: $e'),
        ),
      ],
    );
  }

  /// Deutsche Anzeige des Laufzeit-Rhythmus.
  String _laufzeitLabel(String laufzeit) => switch (laufzeit) {
    'jaehrlich' => 'jährlich',
    _ => laufzeit,
  };
}
