import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../domain/models/kurs_row_data.dart';
import '../kurs_farbe_utils.dart';

/// Farb-Legende der im Kursplan angezeigten Kurse.
///
/// Zeigt je Kurs ein Farbquadrat mit Name und Kampfsportart.
class KursplanLegende extends StatelessWidget {
  final List<KursRowData> kurse;

  const KursplanLegende({super.key, required this.kurse});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (final kurs in kurse)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: parseKursFarbe(kurs.farbe),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: theme.dividerColor),
                ),
              ),
              const Gap(4),
              Text(
                '${kurs.name} (${kurs.kampfsportart})',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
      ],
    );
  }
}
