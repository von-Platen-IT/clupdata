import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../domain/wochen_utils.dart';
import 'dialogs/kurs_list_dialog.dart';
import 'dialogs/kursplan_list_dialog.dart';
import 'providers/kursplan_providers.dart';
import 'widgets/kursplan_legende.dart';
import 'widgets/kursplan_wochen_grid.dart';

/// Kursplan-Screen: zeigt den für die ausgewählte Woche gültigen Kursplan
/// als Wochen-Raster (Spalten = Wochentage, Zeilen = 30-Min-Slots).
///
/// Wochen-Navigation, Plan-Auswahl und Verwaltung von Kursen/Plänen.
class KursplanScreen extends ConsumerWidget {
  const KursplanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final woche = ref.watch(aktuelleWocheProvider);
    final wocheNotifier = ref.read(aktuelleWocheProvider.notifier);
    final plaeneAsync = ref.watch(gueltigeKursplaeneProvider);
    final termineAsync = ref.watch(kursplanTermineProvider);
    final kurseAsync = ref.watch(kurseListProvider);
    final gewaehlterPlan = ref.watch(gewaehlterKursplanProvider);
    final planNotifier = ref.read(gewaehlterKursplanProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Kursplan')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Wochen-Navigation + Plan-Auswahl + Verwaltung
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Vorherige Woche',
                  onPressed: wocheNotifier.zurueck,
                ),
                Text(
                  'Woche ${formatiereWochenBereich(woche)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Nächste Woche',
                  onPressed: wocheNotifier.vor,
                ),
                const Gap(8),
                OutlinedButton(
                  onPressed: wocheNotifier.heute,
                  child: const Text('Heute'),
                ),
                const Gap(24),
                plaeneAsync.when(
                  data: (plaene) => plaene.isEmpty
                      ? const Text('Kein gültiger Kursplan für diese Woche.')
                      : DropdownButton<int>(
                          value: gewaehlterPlan ?? plaene.first.id,
                          items: [
                            for (final plan in plaene)
                              DropdownMenuItem(
                                value: plan.id,
                                child: Text(plan.name),
                              ),
                          ],
                          onChanged: planNotifier.setze,
                        ),
                  loading: () => const SizedBox.shrink(),
                  error: (e, _) => Text('Fehler: $e'),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () => KursListDialog.show(context),
                  icon: const Icon(Icons.sports_martial_arts),
                  label: const Text('Kurse verwalten'),
                ),
                const Gap(8),
                FilledButton.icon(
                  onPressed: () => KursplanListDialog.show(context),
                  icon: const Icon(Icons.edit_calendar),
                  label: const Text('Pläne verwalten'),
                ),
              ],
            ),
            const Gap(16),
            // Wochen-Raster
            Expanded(
              child: SingleChildScrollView(
                child: termineAsync.when(
                  data: (termine) => termine.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'Für diese Woche sind keine Kurse geplant.',
                            ),
                          ),
                        )
                      // RepaintBoundary: Das Raster wird bei Overlays/Hover
                      // nicht komplett neu gezeichnet (Performance-Optimierung).
                      : RepaintBoundary(
                          child: KursplanWochenGrid(
                            termine: termine,
                            wochenAnfang: woche,
                          ),
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Fehler: $e')),
                ),
              ),
            ),
            const Gap(8),
            // Legende
            kurseAsync.when(
              data: (kurse) => kurse.isEmpty
                  ? const SizedBox.shrink()
                  : KursplanLegende(kurse: kurse),
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
