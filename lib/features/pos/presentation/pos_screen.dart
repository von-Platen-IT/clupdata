import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../waren/data/waren_repository.dart';
import '../data/pos_repository.dart';
import 'widgets/tagesabschluss_dialog.dart';
import 'widgets/warenkorb_panel.dart';

/// Echte Kassen-Oberfläche (POS) für den Verkauf an Mitglieder und Walk-ins.
///
/// Layout: Produkt-Grid links, Warenkorb mit Kassier-Panel rechts.
/// Regeln: Bar/Karte → bezahlt + Bestandsabzug · Rechnung → offen.
class PosScreen extends HookConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warenkorb = useState<List<PosPosition>>([]);
    final suchController = useTextEditingController();
    final suchText = useState('');
    final warenAsync = useMemoized(
      () => ref.read(warenRepositoryProvider).getAllWaren(),
      [suchText.value],
    );
    final warenSnapshot = useFuture(warenAsync);
    final alleWaren = warenSnapshot.data ?? const <WarenItem>[];

    final gefiltert = suchText.value.isEmpty
        ? alleWaren
        : alleWaren
              .where(
                (w) => w.bezeichnung.toLowerCase().contains(
                  suchText.value.toLowerCase(),
                ),
              )
              .toList();

    void fuegeHinzu(WarenItem ware) {
      final vorhanden = warenkorb.value.indexWhere(
        (p) => p.wareId == ware.id,
      );
      if (vorhanden >= 0) {
        final alt = warenkorb.value[vorhanden];
        final neu = List<PosPosition>.from(warenkorb.value);
        neu[vorhanden] = PosPosition(
          wareId: alt.wareId,
          bezeichnung: alt.bezeichnung,
          menge: alt.menge + 1,
          einzelpreisBrutto: alt.einzelpreisBrutto,
        );
        warenkorb.value = neu;
      } else {
        warenkorb.value = [
          ...warenkorb.value,
          PosPosition(
            wareId: ware.id,
            bezeichnung: ware.bezeichnung,
            menge: 1,
            einzelpreisBrutto: ware.bruttopreis,
          ),
        ];
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.point_of_sale),
            tooltip: 'Tagesabschluss',
            onPressed: () => TagesabschlussDialog.show(context),
          ),
          const Gap(12),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Produktbereich
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: suchController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Produkt suchen …',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => suchText.value = v,
                  ),
                ),
                Expanded(
                  child: warenSnapshot.connectionState ==
                          ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 180,
                                childAspectRatio: 1.1,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                          itemCount: gefiltert.length,
                          itemBuilder: (context, index) {
                            final ware = gefiltert[index];
                            return _ProduktKachel(ware: ware, onTap: () => fuegeHinzu(ware));
                          },
                        ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          // Warenkorb
          SizedBox(
            width: 380,
            child: WarenkorbPanel(
              positionen: warenkorb.value,
              onMengeGeaendert: (index, menge) {
                final neu = List<PosPosition>.from(warenkorb.value);
                final p = neu[index];
                neu[index] = PosPosition(
                  wareId: p.wareId,
                  bezeichnung: p.bezeichnung,
                  menge: menge,
                  einzelpreisBrutto: p.einzelpreisBrutto,
                );
                warenkorb.value = neu;
              },
              onEntfernen: (index) {
                final neu = List<PosPosition>.from(warenkorb.value);
                neu.removeAt(index);
                warenkorb.value = neu;
              },
              onFertig: () => warenkorb.value = [],
            ),
          ),
        ],
      ),
    );
  }
}

/// Produktkachel im Kassen-Grid.
class _ProduktKachel extends StatelessWidget {
  const _ProduktKachel({required this.ware, required this.onTap});

  final WarenItem ware;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'de_DE', symbol: '€');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ware.bezeichnung,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                currency.format(ware.bruttopreis),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (ware.bestand <= ware.mindestbestand && ware.bestand >= 0)
                Text(
                  'Bestand: ${ware.bestand}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
