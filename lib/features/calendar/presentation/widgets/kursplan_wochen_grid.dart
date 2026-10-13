import 'package:flutter/material.dart';

import '../../domain/models/kursplan_termin_row_data.dart';
import '../../domain/wochen_utils.dart';
import '../kurs_farbe_utils.dart';

/// Wochen-Raster des Kursplans: Spalten = Wochentage (Mo–So),
/// Zeilen = 30-Minuten-Slots (06:00–22:00).
///
/// Jeder Kurstermin wird als farbiger Block über seiner Zeitspanne
/// dargestellt (Hintergrund = `kurs.farbe`). Überlappende Termine
/// teilen sich die Spaltenbreite.
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
    final datumFormat = _zweiStellen;

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
                    '${datumFormat(wochenAnfang.add(Duration(days: tag - 1)).day)}.'
                    '${datumFormat(wochenAnfang.add(Duration(days: tag - 1)).month)}.',
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

    return Container(
      height: gesamtHoehe,
      decoration: BoxDecoration(border: Border.all(color: theme.dividerColor)),
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
              // Kurs-Blöcke (überlappende teilen die Spaltenbreite)
              for (final gruppe in _ueberlappungsGruppen())
                for (var idx = 0; idx < gruppe.length; idx++)
                  _positionierterBlock(
                    gruppe[idx],
                    idx,
                    gruppe.length,
                    spaltenBreite,
                  ),
            ],
          );
        },
      ),
    );
  }

  /// Positioniert einen Kurs-Block im Stack (Pixel-Berechnung via LayoutBuilder).
  Widget _positionierterBlock(
    KursplanTerminRowData termin,
    int spaltenIndex,
    int spaltenAnzahl,
    double spaltenBreite,
  ) {
    final startSlot =
        (termin.startMinuten - KursplanWochenGrid.tagStart) ~/
        KursplanWochenGrid.slotMinuten;
    final endSlot =
        ((termin.endMinuten - KursplanWochenGrid.tagStart) /
                KursplanWochenGrid.slotMinuten)
            .ceil()
            .clamp(startSlot + 1, KursplanWochenGrid.slotAnzahl);

    return Positioned(
      top: startSlot * KursplanWochenGrid.slotHoehe,
      height: (endSlot - startSlot) * KursplanWochenGrid.slotHoehe,
      left: spaltenBreite * spaltenIndex / spaltenAnzahl + 1,
      width: spaltenBreite / spaltenAnzahl - 2,
      child: _KursBlock(termin: termin),
    );
  }

  /// Gruppiert überlappende Termine (für die Spaltenteilung).
  List<List<KursplanTerminRowData>> _ueberlappungsGruppen() {
    final sortiert = [...termine]
      ..sort((a, b) => a.startMinuten.compareTo(b.startMinuten));
    final gruppen = <List<KursplanTerminRowData>>[];
    var aktuell = <KursplanTerminRowData>[];
    var gruppenEnde = -1;

    for (final t in sortiert) {
      if (aktuell.isNotEmpty && t.startMinuten >= gruppenEnde) {
        gruppen.add(aktuell);
        aktuell = [];
        gruppenEnde = -1;
      }
      aktuell.add(t);
      if (t.endMinuten > gruppenEnde) gruppenEnde = t.endMinuten;
    }
    if (aktuell.isNotEmpty) gruppen.add(aktuell);
    return gruppen;
  }
}

/// Farbiger Kursblock mit Name und Zeitbereich.
class _KursBlock extends StatelessWidget {
  final KursplanTerminRowData termin;

  const _KursBlock({required this.termin});

  @override
  Widget build(BuildContext context) {
    final farbe = parseKursFarbe(termin.farbe);
    final textFarbe = kursTextFarbe(farbe);

    return Container(
      margin: const EdgeInsets.all(1),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: farbe,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            termin.kursName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textFarbe,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            termin.endezeit == null
                ? termin.startzeit
                : '${termin.startzeit}–${termin.endezeit}',
            style: TextStyle(fontSize: 10, color: textFarbe),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
