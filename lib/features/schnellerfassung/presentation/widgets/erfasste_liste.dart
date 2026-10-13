import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/models/sitzungs_protokoll_state.dart';
import '../providers/schnellerfassung_providers.dart';

/// Seitenleiste mit Protokoll der laufenden Sitzung.
///
/// Zeigt die erfassten Datensätze als Kontrolle, den Zähler und die
/// (nicht blockierende) Duplikat-Warnung.
class ErfassteListe extends ConsumerWidget {
  const ErfassteListe({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final protokoll = ref.watch(sitzungsProtokollProvider);
    final notifier = ref.read(sitzungsProtokollProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Erfasst in dieser Sitzung (${protokoll.anzahl})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Gap(8),
            if (protokoll.duplikatWarnung != null) ...[
              _WarnHinweis(text: protokoll.duplikatWarnung!),
              const Gap(8),
            ],
            Expanded(
              // ListView.builder: nur sichtbare Zeilen werden gebaut
              // (Performance-Regel „Implement grids and lists thoughtfully").
              child: protokoll.namen.isEmpty
                  ? Text(
                      'Noch keine Datensätze erfasst.',
                      style: theme.textTheme.bodySmall,
                    )
                  : ListView.builder(
                      itemCount: protokoll.namen.length,
                      itemBuilder: (context, i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${i + 1}.  ${protokoll.namen[i]}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ),
            ),
            const Gap(8),
            if (protokoll.namen.isNotEmpty)
              TextButton.icon(
                onPressed: notifier.leere,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Liste leeren'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Optischer Hinweis für die Duplikat-Warnung.
class _WarnHinweis extends StatelessWidget {
  final String text;

  const _WarnHinweis({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, size: 18, color: Colors.orange.shade800),
          const Gap(8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
