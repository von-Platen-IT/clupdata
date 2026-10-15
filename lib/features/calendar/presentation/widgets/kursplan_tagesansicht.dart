import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../domain/kursplan_layout.dart';
import '../../domain/models/kursplan_termin_row_data.dart';
import '../../domain/wochen_utils.dart';
import '../kurs_farbe_utils.dart';

/// Tagesansicht des Kursplans: Zeitstrahl (06:00–22:00) mit den Terminen
/// des Tages.
///
/// Gleichzeitige Termine werden per Lane-Packing nebeneinander dargestellt
/// (siehe [berechnePlatzierungen]). Zeigt auch bei leeren Daten eine leere
/// Vorschau (Zeitstrahl bleibt sichtbar).
class KursplanTagesansicht extends HookWidget {
  const KursplanTagesansicht({
    super.key,
    required this.tag,
    required this.termine,
  });

  final DateTime tag;
  final List<KursplanTerminRowData> termine;

  static const _startStunde = 6;
  static const _endStunde = 22;

  /// Stunde, die beim Öffnen oben sichtbar ist (Kurse finden abends statt).
  static const _initialStunde = 15;

  /// Breite der Zeitspalte (Stundenbeschriftung).
  static const double _zeitSpalteBreite = 56;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Initialer Scroll-Offset: 15:00 Uhr oben, damit abendliche Kurse ohne
    // manuelles Scrollen sichtbar sind. Flutter clampt auf maxScrollExtent.
    final scrollController = useScrollController(
      initialScrollOffset: (_initialStunde - _startStunde) * 60.0,
    );
    final tagesTermine = termine
        .where((t) => t.wochentag == tag.weekday)
        .toList();
    final platzierungen = berechnePlatzierungen(tagesTermine);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '${wochentagNamen[tag.weekday - 1]}, '
            '${tag.day.toString().padLeft(2, '0')}.'
            '${tag.month.toString().padLeft(2, '0')}.${tag.year}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            child: SizedBox(
              height: (_endStunde - _startStunde) * 60.0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bereichBreite =
                      constraints.maxWidth - _zeitSpalteBreite - 8;
                  return Stack(
                    children: [
                      // Stundenlinien + Beschriftung
                      for (
                        var stunde = _startStunde;
                        stunde <= _endStunde;
                        stunde++
                      )
                        Positioned(
                          top: (stunde - _startStunde) * 60.0,
                          left: 0,
                          right: 0,
                          child: Row(
                            children: [
                              SizedBox(
                                width: _zeitSpalteBreite,
                                child: Text(
                                  '${stunde.toString().padLeft(2, '0')}:00',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              const Expanded(child: Divider(height: 1)),
                            ],
                          ),
                        ),
                      // Termine (gleichzeitige nebeneinander)
                      for (final p in platzierungen)
                        _TerminBlock(
                          platzierung: p,
                          startStunde: _startStunde,
                          bereichBreite: bereichBreite,
                        ),
                      // Leere Vorschau-Hinweis
                      if (tagesTermine.isEmpty)
                        Positioned(
                          top: 120,
                          left: _zeitSpalteBreite,
                          right: 0,
                          child: Text(
                            'Keine Kurse an diesem Tag.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.disabledColor,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ein Terminblock im Tages-Zeitstrahl.
class _TerminBlock extends StatelessWidget {
  const _TerminBlock({
    required this.platzierung,
    required this.startStunde,
    required this.bereichBreite,
  });

  final TerminPlatzierung platzierung;
  final int startStunde;

  /// Verfügbare Breite für alle Terminblöcke (ohne Zeitspalte).
  final double bereichBreite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final termin = platzierung.termin;
    final startMinuten = termin.startMinuten;
    final endeMinuten = termin.endMinuten;
    final oben = (startMinuten - startStunde * 60).toDouble();
    final hoehe = (endeMinuten - startMinuten).clamp(30, 240).toDouble();

    final laneBreite = bereichBreite / platzierung.laneAnzahl;
    final links = 60.0 + laneBreite * platzierung.laneIndex;
    final breite = (laneBreite - 4).clamp(0.0, double.infinity).toDouble();

    final farbe = parseKursFarbe(termin.farbe);

    return Positioned(
      top: oben,
      left: links,
      width: breite,
      height: hoehe,
      child: Tooltip(
        message:
            '${termin.kursName}\n${termin.kampfsportart}\n'
            '${termin.startzeit} – ${termin.endezeit ?? 'offen'}',
        waitDuration: const Duration(milliseconds: 400),
        child: Card(
          color: farbe.withValues(alpha: 0.25),
          margin: const EdgeInsets.all(1),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final zeigeZeit = constraints.maxHeight >= 48;
                // OverflowBox: Inhalt darf die feste Blockhöhe überragen,
                // ohne einen RenderFlex-Overflow zu melden (Card kappt).
                return OverflowBox(
                  alignment: Alignment.topLeft,
                  maxHeight: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        termin.kursName,
                        style: zeigeZeit
                            ? theme.textTheme.titleSmall
                            : theme.textTheme.bodySmall,
                        maxLines: zeigeZeit ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (zeigeZeit)
                        Text(
                          '${termin.startzeit} – ${termin.endezeit ?? 'offen'}',
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
