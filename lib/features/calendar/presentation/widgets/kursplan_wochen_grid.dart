import 'package:flutter/material.dart';

import '../../../../core/utils/datum_utils.dart';
import '../../domain/kursplan_layout.dart';
import '../../domain/models/kursplan_termin_row_data.dart';
import '../../domain/wochen_utils.dart';
import '../kurs_farbe_utils.dart';

/// Wochen-Raster des Kursplans: Spalten = Wochentage (Mo–So),
/// Zeilen = 30-Minuten-Slots (06:00–22:00).
///
/// Jeder Kurstermin wird als farbiger Block über seiner Zeitspanne
/// dargestellt (Hintergrund = `kurs.farbe`). **Gleichzeitige** Termine werden
/// per Lane-Packing nebeneinander angeordnet (siehe [berechnePlatzierungen]);
/// der Blockinhalt passt sich der verfügbaren Höhe/Breite an, sodass kein
/// Overflow entsteht.
///
/// Hinweis Widget-Regel: Das Raster ist eine Kalender-Darstellung
/// (Zeit-Raster), keine Datentabelle – die PlutoGrid-Regel (Data-Grids)
/// findet keine Anwendung.
class KursplanWochenGrid extends StatelessWidget {
  final List<KursplanTerminRowData> termine;

  /// Montag der dargestellten Woche (für die Datums-Anzeige).
  final DateTime wochenAnfang;

  const KursplanWochenGrid({
    super.key,
    required this.termine,
    required this.wochenAnfang,
  });

  /// Tagesbeginn der Zeitachse (06:00).
  static const int tagStart = 6 * 60;

  /// Tagesende der Zeitachse (22:00).
  static const int tagEnde = 22 * 60;

  /// Slot-Dauer in Minuten.
  static const int slotMinuten = 30;

  /// Höhe eines Slots in Pixeln.
  static const double slotHoehe = 30;

  /// Anzahl der Slots pro Tag.
  static int get slotAnzahl => (tagEnde - tagStart) ~/ slotMinuten;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gesamtHoehe = slotAnzahl * slotHoehe;

    return Column(
      children: [
        // Kopfzeile: Wochentage mit Datum
        Row(
          children: [
            const SizedBox(width: 56),
            for (var tag = 1; tag <= 7; tag++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${wochentagNamen[tag - 1]}\n'
                    '${_zweiStellen(addiereTage(wochenAnfang, tag - 1).day)}.'
                    '${_zweiStellen(addiereTage(wochenAnfang, tag - 1).month)}.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Zeit-Raster
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zeitspalte
            SizedBox(
              width: 56,
              height: gesamtHoehe,
              child: Column(
                children: [
                  for (var i = 0; i < slotAnzahl; i++)
                    SizedBox(
                      height: slotHoehe,
                      child: Text(
                        i.isEven
                            ? formatiereZeit(tagStart + i * slotMinuten)
                            : '',
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
            ),
            // Wochentags-Spalten
            for (var tag = 1; tag <= 7; tag++)
              Expanded(
                child: _TagSpalte(
                  termine: termine.where((t) => t.wochentag == tag).toList(),
                  gesamtHoehe: gesamtHoehe,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

String _zweiStellen(int wert) => wert.toString().padLeft(2, '0');

/// Einzelne Wochentag-Spalte mit Slot-Linien und Kurs-Blöcken.
class _TagSpalte extends StatelessWidget {
  final List<KursplanTerminRowData> termine;
  final double gesamtHoehe;

  const _TagSpalte({required this.termine, required this.gesamtHoehe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platzierungen = berechnePlatzierungen(termine);

    // Hinweis: DecoratedBox statt Container – Container würde über
    // BoxDecoration.border ein implizites Padding (1px/Kante) erzeugen und
    // den Inhalt um 2px verkleinern (Overflow der Slot-Spalte).
    return SizedBox(
      height: gesamtHoehe,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final spaltenBreite = constraints.maxWidth;
            return Stack(
              children: [
                // Slot-Linien
                Column(
                  children: [
                    for (var i = 0; i < KursplanWochenGrid.slotAnzahl; i++)
                      Container(
                        height: KursplanWochenGrid.slotHoehe,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // Kurs-Blöcke (gleichzeitige Termine teilen die Spaltenbreite)
                for (final p in platzierungen)
                  _positionierterBlock(p, platzierungen, spaltenBreite),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Positioniert einen Kurs-Block im Stack (Pixel-Berechnung via LayoutBuilder).
  Widget _positionierterBlock(
    TerminPlatzierung platzierung,
    List<TerminPlatzierung> alle,
    double spaltenBreite,
  ) {
    final termin = platzierung.termin;

    // Zeitachse auf den Anzeigebereich [tagStart, tagEnde] begrenzen.
    final startSlot =
        ((termin.startMinuten - KursplanWochenGrid.tagStart) ~/
                KursplanWochenGrid.slotMinuten)
            .clamp(0, KursplanWochenGrid.slotAnzahl - 1)
            .toInt();
    final endSlot =
        ((termin.endMinuten - KursplanWochenGrid.tagStart) /
                KursplanWochenGrid.slotMinuten)
            .ceil()
            .clamp(startSlot + 1, KursplanWochenGrid.slotAnzahl)
            .toInt();

    final laneBreite = spaltenBreite / platzierung.laneAnzahl;
    final links = laneBreite * platzierung.laneIndex + 1;
    final breite = (laneBreite - 2).clamp(0.0, double.infinity).toDouble();

    final parallelNamen = [
      for (final o in alle)
        if (!identical(o.termin, termin) && ueberlappt(termin, o.termin))
          o.termin.kursName,
    ];

    return Positioned(
      top: startSlot * KursplanWochenGrid.slotHoehe,
      height: (endSlot - startSlot) * KursplanWochenGrid.slotHoehe,
      left: links,
      width: breite,
      child: _KursBlock(platzierung: platzierung, parallelNamen: parallelNamen),
    );
  }
}

/// Farbiger Kursblock mit responsivem Inhalt, Parallel-Badge und Tooltip.
class _KursBlock extends StatelessWidget {
  final TerminPlatzierung platzierung;

  /// Namen der gleichzeitig laufenden Kurse (für den Tooltip).
  final List<String> parallelNamen;

  const _KursBlock({required this.platzierung, required this.parallelNamen});

  @override
  Widget build(BuildContext context) {
    final termin = platzierung.termin;
    final farbe = parseKursFarbe(termin.farbe);
    final textFarbe = kursTextFarbe(farbe);
    final zeit = termin.endezeit == null
        ? termin.startzeit
        : '${termin.startzeit}–${termin.endezeit}';

    return Tooltip(
      message: _tooltipText(termin),
      waitDuration: const Duration(milliseconds: 400),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: farbe,
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hoehe = constraints.maxHeight;
              final breite = constraints.maxWidth;
              // Zeit nur bei ausreichender Höhe/Breite (verhindert Overflow).
              final zeigeZeit = hoehe >= 56 && breite >= 90;
              final zeigeName = hoehe >= 20 && breite >= 24;

              return Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      3,
                      3,
                      platzierung.istParallel ? 14 : 3,
                      3,
                    ),
                    // OverflowBox: Inhalt darf die feste Blockhöhe überragen,
                    // ohne einen RenderFlex-Overflow zu melden (ClipRRect kappt).
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      maxHeight: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (zeigeName)
                            Text(
                              termin.kursName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: textFarbe,
                              ),
                              maxLines: zeigeZeit ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (zeigeZeit)
                            Text(
                              zeit,
                              style: TextStyle(fontSize: 10, color: textFarbe),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (platzierung.istParallel)
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Icon(
                        Icons.people_alt_outlined,
                        size: 11,
                        color: textFarbe,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Tooltip mit Kursname, Kampfsportart, Zeit und parallelen Kursen.
  String _tooltipText(KursplanTerminRowData termin) {
    final zeit = termin.endezeit == null
        ? 'ab ${termin.startzeit}'
        : '${termin.startzeit}–${termin.endezeit}';
    final buffer = StringBuffer()
      ..writeln(termin.kursName)
      ..writeln(termin.kampfsportart)
      ..write(zeit);
    if (parallelNamen.isNotEmpty) {
      buffer.write('\nParallel: ${parallelNamen.join(', ')}');
    }
    return buffer.toString();
  }
}
