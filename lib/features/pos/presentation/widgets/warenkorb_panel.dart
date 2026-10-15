import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/database.dart';
import '../../../billing/domain/models/zahlungsart.dart';
import '../../../members/data/members_repository.dart';
import '../../data/pos_repository.dart';

/// Warenkorb-Panel der Kasse mit Kundenauswahl, Zahlart und Kassieren.
///
/// Bar/Karte → Rechnung `bezahlt` + Bestandsabzug · Rechnung → `offen`.
class WarenkorbPanel extends HookConsumerWidget {
  const WarenkorbPanel({
    super.key,
    required this.positionen,
    required this.onMengeGeaendert,
    required this.onEntfernen,
    required this.onFertig,
  });

  final List<PosPosition> positionen;
  final void Function(int index, double menge) onMengeGeaendert;
  final void Function(int index) onEntfernen;

  /// Wird nach erfolgreichem Kassieren aufgerufen (leert den Warenkorb).
  final VoidCallback onFertig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    final zahlungsart = useState(Zahlungsart.bar);
    final mitglied = useState<Mitglied?>(null);
    final kundeNameController = useTextEditingController();
    final isSaving = useState(false);

    final summe = positionen.fold<double>(0, (s, p) => s + p.gesamtBrutto);

    Future<void> kassieren() async {
      if (positionen.isEmpty) return;
      isSaving.value = true;
      try {
        final repo = ref.read(posRepositoryProvider);
        final ergebnis = await repo.kassiereVorgang(
          positionen: positionen,
          zahlungsart: zahlungsart.value,
          mitgliedId: mitglied.value?.id,
          kundeName: mitglied.value == null && kundeNameController.text.isNotEmpty
              ? kundeNameController.text
              : null,
        );
        onFertig();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ergebnis.istBezahlt
                    ? 'Kassiert: ${ergebnis.rechnungsnummer} – '
                          '${currency.format(ergebnis.gesamtBrutto)} bezahlt.'
                    : 'Rechnung ${ergebnis.rechnungsnummer} erstellt – '
                          '${currency.format(ergebnis.gesamtBrutto)} offen.',
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Kassieren: $e')),
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Warenkorb', style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          child: positionen.isEmpty
              ? const Center(child: Text('Warenkorb ist leer.'))
              : ListView.builder(
                  itemCount: positionen.length,
                  itemBuilder: (context, index) {
                    final p = positionen[index];
                    return ListTile(
                      dense: true,
                      title: Text(p.bezeichnung),
                      subtitle: Text(currency.format(p.einzelpreisBrutto)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: p.menge > 1
                                ? () => onMengeGeaendert(index, p.menge - 1)
                                : null,
                          ),
                          Text('${p.menge.toStringAsFixed(0)}'),
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () =>
                                onMengeGeaendert(index, p.menge + 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => onEntfernen(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kunde: Mitglied oder Walk-in
              Autocomplete<Mitglied>(
                displayStringForOption: (m) => '${m.name}, ${m.vorname}',
                optionsBuilder: (textEditingValue) async {
                  if (textEditingValue.text.length < 2) return const [];
                  final repo = ref.read(membersRepositoryProvider);
                  return repo.searchMembers(textEditingValue.text);
                },
                onSelected: (m) => mitglied.value = m,
                fieldViewBuilder:
                    (context, controller, focusNode, onSubmitted) {
                      controller.text = mitglied.value == null
                          ? controller.text
                          : '${mitglied.value!.name}, ${mitglied.value!.vorname}';
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Mitglied suchen (optional)',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
              ),
              if (mitglied.value == null) ...[
                const Gap(8),
                TextField(
                  controller: kundeNameController,
                  decoration: const InputDecoration(
                    labelText: 'Walk-in Name (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const Gap(12),
              // Zahlart
              Wrap(
                spacing: 8,
                children: [
                  for (final art in const [
                    Zahlungsart.bar,
                    Zahlungsart.karte,
                    Zahlungsart.ueberweisung,
                  ])
                    ChoiceChip(
                      label: Text(art.label),
                      selected: zahlungsart.value == art,
                      onSelected: (_) => zahlungsart.value = art,
                    ),
                ],
              ),
              const Gap(12),
              Row(
                children: [
                  Text('Summe', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  Text(
                    currency.format(summe),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const Gap(12),
              FilledButton.icon(
                icon: const Icon(Icons.point_of_sale),
                label: Text(
                  zahlungsart.value == Zahlungsart.ueberweisung
                      ? 'Rechnung erstellen'
                      : 'Kassieren ${currency.format(summe)}',
                ),
                onPressed: positionen.isEmpty || isSaving.value
                    ? null
                    : kassieren,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
