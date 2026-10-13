import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../domain/models/abrechnungs_modus.dart';
import '../providers/rechnungslegung_wizard_provider.dart';
import 'kurs_auswahl.dart';
import 'mitglied_auswahl.dart';

/// Wizard-Schritt 2: Auswahloberfläche, abhängig vom Abrechnungsmodus.
class SchrittAuswahl extends ConsumerWidget {
  const SchrittAuswahl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rechnungslegungWizardProvider);
    return switch (state.modus) {
      AbrechnungsModus.zeitperioden => const _ZeitraumHinweis(),
      AbrechnungsModus.einzelnesMitglied => const MitgliedAuswahl(multi: false),
      AbrechnungsModus.ausgewaehlteMitglieder => const MitgliedAuswahl(
        multi: true,
      ),
      AbrechnungsModus.kurse => const KursAuswahl(),
    };
  }
}

/// Hinweistext für den Modus „Zeitperioden" (keine Zusatzauswahl nötig).
class _ZeitraumHinweis extends StatelessWidget {
  const _ZeitraumHinweis();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Alle Mitglieder mit gültigem Vertrag werden berücksichtigt.'),
        Gap(8),
        Text('Der Abrechnungszeitraum wird im nächsten Schritt gewählt.'),
      ],
    );
  }
}
