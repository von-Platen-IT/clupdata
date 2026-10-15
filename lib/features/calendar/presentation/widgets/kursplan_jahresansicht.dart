import 'package:flutter/material.dart';

import '../../domain/wochen_utils.dart';

/// Jahresansicht des Kursplans: 12 Monats-Spalten mit Kalenderwochen.
///
/// - Klick auf eine **Kalenderwoche** → Wochenansicht dieser Woche
/// - Klick auf den **Monatsnamen** (ohne KW) → Monatsansicht
class KursplanJahresansicht extends StatelessWidget {
  const KursplanJahresansicht({
    super.key,
    required this.jahr,
    required this.onWocheGewaehlt,
    required this.onMonatGewaehlt,
  });

  final int jahr;

  /// Wird bei Klick auf eine Kalenderwoche (Montag der KW) aufgerufen.
  final ValueChanged<DateTime> onWocheGewaehlt;

  /// Wird bei Klick auf den Monatsnamen aufgerufen.
  final ValueChanged<DateTime> onMonatGewaehlt;

  static const _monatsNamen = [
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsiv: 12 Spalten bei viel Platz, sonst 6/4/3 Spalten.
        final spalten = constraints.maxWidth > 1200
            ? 12
            : constraints.maxWidth > 800
            ? 6
            : constraints.maxWidth > 500
            ? 4
            : 3;
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: spalten,
            childAspectRatio: 0.55,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 12,
          itemBuilder: (context, index) => _MonatsSpalte(
            monat: DateTime(jahr, index + 1, 1),
            monatsName: _monatsNamen[index],
            onWocheGewaehlt: onWocheGewaehlt,
            onMonatGewaehlt: onMonatGewaehlt,
          ),
        );
      },
    );
  }
}

/// Eine Monatsspalte der Jahresansicht mit allen Kalenderwochen.
class _MonatsSpalte extends StatelessWidget {
  const _MonatsSpalte({
    required this.monat,
    required this.monatsName,
    required this.onWocheGewaehlt,
    required this.onMonatGewaehlt,
  });

  final DateTime monat;
  final String monatsName;
  final ValueChanged<DateTime> onWocheGewaehlt;
  final ValueChanged<DateTime> onMonatGewaehlt;

  @override
  Widget build(BuildContext context) {
    final wochen = wochenImMonat(monat);
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Monatsname als Button → Monatsansicht
          InkWell(
            onTap: () => onMonatGewaehlt(monat),
            child: Container(
              color: theme.colorScheme.primaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Text(
                monatsName,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: wochen.length,
              itemBuilder: (context, index) {
                final montag = wochen[index];
                final kw = kalenderwoche(montag);
                return InkWell(
                  onTap: () => onWocheGewaehlt(montag),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 6,
                    ),
                    child: Text(
                      'KW $kw',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
