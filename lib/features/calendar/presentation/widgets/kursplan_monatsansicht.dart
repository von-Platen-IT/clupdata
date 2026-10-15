import 'package:flutter/material.dart';

import '../../domain/models/kursplan_termin_row_data.dart';
import '../../domain/wochen_utils.dart';

/// Monatsansicht des Kursplans: klassisches Kalender-Raster (Mo–So).
///
/// - Klick auf einen **Tag** → Tagesansicht
/// - Klick auf die **Wochennummer** (links) → Wochenansicht
/// - Kleine Farbmarkierungen zeigen Kurstage an (leere Vorschau möglich)
class KursplanMonatsansicht extends StatelessWidget {
  const KursplanMonatsansicht({
    super.key,
    required this.monat,
    required this.termine,
    required this.onTagGewaehlt,
    required this.onWocheGewaehlt,
  });

  /// Beliebiger Tag im anzuzeigenden Monat.
  final DateTime monat;
  final List<KursplanTerminRowData> termine;
  final ValueChanged<DateTime> onTagGewaehlt;
  final ValueChanged<DateTime> onWocheGewaehlt;

  @override
  Widget build(BuildContext context) {
    final wochen = monatsraster(monat);
    final theme = Theme.of(context);
    final heute = DateTime.now();

    return Column(
      children: [
        // Wochentags-Kopfzeile
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 40), // Platz für Wochennummer
              for (final tag in wochentagNamen)
                Expanded(
                  child: Center(
                    child: Text(
                      tag.substring(0, 2),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: wochen.length,
            itemBuilder: (context, index) {
              final woche = wochen[index];
              final montag = woche.first;
              return Row(
                children: [
                  // Wochennummer → Wochenansicht
                  SizedBox(
                    width: 40,
                    child: InkWell(
                      onTap: () => onWocheGewaehlt(montag),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'KW ${kalenderwoche(montag)}',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  for (final tag in woche)
                    Expanded(
                      child: _TagZelle(
                        tag: tag,
                        istHeute: _gleicherTag(tag, heute),
                        istAktuellerMonat: tag.month == monat.month,
                        termine: _termineFuerTag(tag),
                        onTap: () => onTagGewaehlt(tag),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<KursplanTerminRowData> _termineFuerTag(DateTime tag) {
    // Termine sind wöchentliche Templates: wochentag 1 = Montag.
    return termine.where((t) => t.wochentag == tag.weekday).toList();
  }

  bool _gleicherTag(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Eine Tageszelle im Monatsraster.
class _TagZelle extends StatelessWidget {
  const _TagZelle({
    required this.tag,
    required this.istHeute,
    required this.istAktuellerMonat,
    required this.termine,
    required this.onTap,
  });

  final DateTime tag;
  final bool istHeute;
  final bool istAktuellerMonat;
  final List<KursplanTerminRowData> termine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: istHeute
              ? theme.colorScheme.primaryContainer
              : istAktuellerMonat
              ? null
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(4),
          border: istHeute
              ? Border.all(color: theme.colorScheme.primary)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${tag.day}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: istHeute ? FontWeight.bold : null,
                color: istAktuellerMonat ? null : theme.disabledColor,
              ),
            ),
            // Kurstage als kleine Farbmarkierungen (leere Vorschau möglich).
            Wrap(
              spacing: 2,
              runSpacing: 2,
              alignment: WrapAlignment.center,
              children: [
                for (final t in termine.take(3))
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _parseFarbe(t.farbe),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (termine.length > 3)
                  Text('+${termine.length - 3}', style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _parseFarbe(String hex) {
    final wert = hex.replaceFirst('#', '');
    final intVal = int.tryParse(wert, radix: 16);
    return intVal == null ? Colors.grey : Color(0xFF000000 | intVal);
  }
}
