import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/models/abrechnungs_modus.dart';
import '../providers/rechnungslegung_wizard_provider.dart';

/// Wizard-Schritt 1: Auswahl des Abrechnungsmodus.
class SchrittModus extends ConsumerWidget {
  const SchrittModus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rechnungslegungWizardProvider);
    final notifier = ref.read(rechnungslegungWizardProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Was soll abgerechnet werden?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Gap(8),
        for (final modus in AbrechnungsModus.values)
          RadioListTile<AbrechnungsModus>(
            value: modus,
            groupValue: state.modus,
            onChanged: (m) {
              if (m != null) notifier.setModus(m);
            },
            title: Text(modus.label),
            subtitle: Text(modus.description),
          ),
      ],
    );
  }
}
