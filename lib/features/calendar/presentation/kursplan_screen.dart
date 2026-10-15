import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/kursplan_layout.dart';
import '../domain/models/kursplan_ansicht.dart';
import '../domain/models/kursplan_row_data.dart';
import '../domain/models/kursplan_termin_row_data.dart';
import '../domain/wochen_utils.dart';
import 'dialogs/kurs_list_dialog.dart';
import 'dialogs/kursplan_list_dialog.dart';
import 'providers/kursplan_providers.dart';
import 'widgets/kursplan_jahresansicht.dart';
import 'widgets/kursplan_legende.dart';
import 'widgets/kursplan_monatsansicht.dart';
import 'widgets/kursplan_tagesansicht.dart';
import 'widgets/kursplan_wochen_grid.dart';

/// Kursplan-Screen mit Kalender-Ansichten (Jahr/Monat/Woche/Tag).
///
/// Initial wird die **aktuelle Wochenansicht** gezeigt. Die oberste Zeile
/// enthält das angezeigte Jahr, das Ansichts-Dropdown und den DatePicker.
class KursplanScreen extends ConsumerWidget {
  const KursplanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = ref.watch(kursplanAnsichtSteuerungProvider);
    final steuerung = ref.read(kursplanAnsichtSteuerungProvider.notifier);
    final plaeneAsync = ref.watch(gueltigeKursplaeneProvider);
    final termineAsync = ref.watch(kursplanTermineProvider);
    final kurseAsync = ref.watch(kurseListProvider);
    final gewaehlterPlan = ref.watch(gewaehlterKursplanProvider);
    final planNotifier = ref.read(gewaehlterKursplanProvider.notifier);
    final termine = termineAsync.value ?? const <KursplanTerminRowData>[];
    final parallelKursIds = paralleleKursIds(termine);

    return Scaffold(
      appBar: AppBar(title: const Text('Kursplan')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Toolbar(
              zustand: zustand,
              steuerung: steuerung,
              plaeneAsync: plaeneAsync,
              gewaehlterPlan: gewaehlterPlan,
              onPlanGewaehlt: planNotifier.setze,
            ),
            const Gap(12),
            // Ansichts-Bereich (Riverpod 3: keine when()-API – Properties nutzen)
            Expanded(
              child: termineAsync.isLoading && termineAsync.value == null
                  ? const Center(child: CircularProgressIndicator())
                  : termineAsync.hasError && termineAsync.value == null
                  ? Center(child: Text('Fehler: ${termineAsync.error}'))
                  : _AnsichtsBereich(
                      zustand: zustand,
                      termine: termine,
                      steuerung: steuerung,
                    ),
            ),
            const Gap(8),
            // Legende (auf maxHeight begrenzt – kein Overflow bei vielen Kursen)
            if (kurseAsync.isLoading && kurseAsync.value == null)
              const SizedBox.shrink()
            else if (kurseAsync.hasError && kurseAsync.value == null)
              Text('Legende: ${kurseAsync.error}')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 88),
                child: SingleChildScrollView(
                  child: KursplanLegende(
                    kurse: kurseAsync.value ?? const [],
                    parallelKursIds: parallelKursIds,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Oberste Zeile: Jahr, Ansichts-Dropdown, DatePicker + Navigation.
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.zustand,
    required this.steuerung,
    required this.plaeneAsync,
    required this.gewaehlterPlan,
    required this.onPlanGewaehlt,
  });

  final KursplanAnsichtZustand zustand;
  final KursplanAnsichtSteuerung steuerung;
  final AsyncValue<List<KursplanRowData>> plaeneAsync;
  final int gewaehlterPlan;
  final void Function(int?) onPlanGewaehlt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Angezeigtes Jahr
        Text(
          '${zustand.fokus.year}',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        // Ansichts-Dropdown
        DropdownButton<KursplanAnsicht>(
          value: zustand.ansicht,
          items: [
            for (final ansicht in KursplanAnsicht.values)
              DropdownMenuItem(value: ansicht, child: Text(ansicht.label)),
          ],
          onChanged: (a) {
            if (a != null) steuerung.setzeAnsicht(a);
          },
        ),
        // DatePicker
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(_formatiereFokus(zustand)),
          onPressed: () async {
            final datum = await showDatePicker(
              context: context,
              initialDate: zustand.fokus,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (datum != null) steuerung.setzeFokus(datum);
          },
        ),
        // Navigation
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Zurück',
          onPressed: steuerung.zurueck,
        ),
        OutlinedButton(onPressed: steuerung.heute, child: const Text('Heute')),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Vor',
          onPressed: steuerung.vor,
        ),
        // Hinweis: In Wrap sind nur SizedBox erlaubt (Gap/Spacer brauchen Flex).
        const SizedBox(width: 16),
        // Plan-Auswahl (Dropdown-Fix: value muss in items enthalten sein)
        _buildPlanAuswahl(context),
        OutlinedButton.icon(
          onPressed: () => KursListDialog.show(context),
          icon: const Icon(Icons.sports_martial_arts),
          label: const Text('Kurse verwalten'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => KursplanListDialog.show(context),
          icon: const Icon(Icons.edit_calendar),
          label: const Text('Pläne verwalten'),
        ),
      ],
    );
  }

  /// Plan-Auswahl mit Riverpod-3-sicherer Async-Behandlung (keine when()-API).
  Widget _buildPlanAuswahl(BuildContext context) {
    final plaene = plaeneAsync.value;
    if (plaeneAsync.isLoading && plaene == null) return const SizedBox.shrink();
    if (plaeneAsync.hasError && plaene == null) {
      return Text('Fehler: ${plaeneAsync.error}');
    }
    if (plaene == null || plaene.isEmpty) {
      return const Text('Kein gültiger Kursplan für diesen Zeitraum.');
    }
    final gueltigeIds = plaene.map((p) => p.id).toSet();
    final value = gueltigeIds.contains(gewaehlterPlan)
        ? gewaehlterPlan
        : plaene.first.id;
    return DropdownButton<int>(
      value: value,
      items: [
        for (final plan in plaene)
          DropdownMenuItem(value: plan.id, child: Text(plan.name)),
      ],
      onChanged: onPlanGewaehlt,
    );
  }

  String _formatiereFokus(KursplanAnsichtZustand z) {
    switch (z.ansicht) {
      case KursplanAnsicht.jahr:
        return '${z.fokus.year}';
      case KursplanAnsicht.monat:
        return DateFormat('MMMM yyyy', 'de_DE').format(z.fokus);
      case KursplanAnsicht.woche:
        return 'KW ${kalenderwoche(z.fokus)} · ${formatiereWochenBereich(z.fokus)}';
      case KursplanAnsicht.tag:
        return DateFormat('EEEE, dd.MM.yyyy', 'de_DE').format(z.fokus);
    }
  }
}

/// Schaltet je nach Ansicht zwischen Jahr/Monat/Woche/Tag um.
class _AnsichtsBereich extends StatelessWidget {
  const _AnsichtsBereich({
    required this.zustand,
    required this.termine,
    required this.steuerung,
  });

  final KursplanAnsichtZustand zustand;
  final List<KursplanTerminRowData> termine;
  final KursplanAnsichtSteuerung steuerung;

  @override
  Widget build(BuildContext context) {
    switch (zustand.ansicht) {
      case KursplanAnsicht.jahr:
        return KursplanJahresansicht(
          jahr: zustand.fokus.year,
          onWocheGewaehlt: (montag) {
            steuerung
              ..setzeFokus(montag)
              ..setzeAnsicht(KursplanAnsicht.woche);
          },
          onMonatGewaehlt: (monat) {
            steuerung
              ..setzeFokus(monat)
              ..setzeAnsicht(KursplanAnsicht.monat);
          },
        );
      case KursplanAnsicht.monat:
        return KursplanMonatsansicht(
          monat: zustand.fokus,
          termine: termine,
          onTagGewaehlt: (tag) {
            steuerung
              ..setzeFokus(tag)
              ..setzeAnsicht(KursplanAnsicht.tag);
          },
          onWocheGewaehlt: (montag) {
            steuerung
              ..setzeFokus(montag)
              ..setzeAnsicht(KursplanAnsicht.woche);
          },
        );
      case KursplanAnsicht.woche:
        // Auch bei leeren Daten bleibt das Wochen-Raster als leere Vorschau
        // sichtbar (Anforderung). SingleChildScrollView verhindert Overflow
        // bei Fensterhöhen, die für das feste Raster nicht ausreichen.
        return SingleChildScrollView(
          child: RepaintBoundary(
            child: KursplanWochenGrid(
              termine: termine,
              wochenAnfang: montagVon(zustand.fokus),
            ),
          ),
        );
      case KursplanAnsicht.tag:
        // Die Tagesansicht bringt einen eigenen Scroll-Viewport mit und
        // erwartet eine BEGRENZTE Höhe (Expanded). Daher KEIN äußerer
        // SingleChildScrollView – sonst unbounded height → RenderFlex-Fehler.
        return KursplanTagesansicht(tag: zustand.fokus, termine: termine);
    }
  }
}
