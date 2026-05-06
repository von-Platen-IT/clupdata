import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Zeigt den Kursplan/Kalender mit wöchentlichen Trainingseinheiten an.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Kursplan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Wöchentlicher Kursplan', style: theme.textTheme.headlineSmall),
          const Gap(8),
          Text(
            'Hier werden die regelmäßigen Trainingseinheiten und Kurse '
            'der Woche angezeigt.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Gap(24),

          // Wochentage
          ...[
            'Montag',
            'Dienstag',
            'Mittwoch',
            'Donnerstag',
            'Freitag',
            'Samstag',
          ].map(
            (day) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  Icons.calendar_today,
                  color: theme.colorScheme.primary,
                ),
                title: Text(day),
                subtitle: const Text('Kurse werden konfiguriert...'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
