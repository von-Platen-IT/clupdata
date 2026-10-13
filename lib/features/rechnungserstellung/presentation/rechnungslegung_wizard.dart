import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../common_widgets/app_edit_dialog_scaffold.dart';
import 'providers/rechnungslegung_wizard_provider.dart';
import 'steps/schritt_auswahl.dart';
import 'steps/schritt_ergebnis.dart';
import 'steps/schritt_modus.dart';
import 'steps/schritt_vorschau.dart';
import 'steps/schritt_zeitraum_optionen.dart';

/// Einheitlicher Rechnungsstellungs-Assistent (5 Schritte).
///
/// Ersetzt die bisherigen `RechnungslegungDialog`- und
/// `BeitraegeBatchDialog`-Implementierungen und unterstützt die vier
/// Abrechnungsmodi (Zeitperioden, Einzelmitglied, Auswahl, Kurse).
class RechnungslegungWizardDialog extends HookConsumerWidget {
  const RechnungslegungWizardDialog({super.key});

  /// Opens the wizard dialog.
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RechnungslegungWizardDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rechnungslegungWizardProvider);
    final notifier = ref.read(rechnungslegungWizardProvider.notifier);
    final isProcessing = useState(false);

    Future<void> weiter() async {
      if (state.schritt == 3) {
        // Vorschau wird explizit geladen – siehe [RechnungslegungWizard.ladeVorschau].
        isProcessing.value = true;
        try {
          await notifier.ladeVorschau();
        } finally {
          isProcessing.value = false;
        }
      } else {
        notifier.setSchritt(state.schritt + 1);
      }
    }

    Future<void> ausfuehren() async {
      isProcessing.value = true;
      try {
        await notifier.fuehreAus();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler bei der Erstellung: $e')),
          );
        }
      } finally {
        isProcessing.value = false;
      }
    }

    final String saveLabel;
    final IconData saveIcon;
    final VoidCallback onSave;
    if (state.schritt < 4) {
      saveLabel = 'Weiter';
      saveIcon = Icons.arrow_forward;
      onSave = weiter;
    } else if (state.schritt == 4) {
      saveLabel = '${state.zuErstellenAnzahl} erstellen';
      saveIcon = Icons.check;
      onSave = ausfuehren;
    } else {
      saveLabel = 'Schließen';
      saveIcon = Icons.check;
      onSave = () => Navigator.of(context).pop();
    }

    return AppEditDialogScaffold(
      title: 'Beiträge abrechnen – Schritt ${state.schritt} von 5',
      contentWidth: 860,
      isSaving: isProcessing.value,
      isSaveEnabled: state.schritt != 4 || state.zuErstellenAnzahl > 0,
      saveLabel: saveLabel,
      saveIcon: saveIcon,
      onSave: onSave,
      additionalActions: [
        if (state.schritt > 1 && state.schritt < 5)
          TextButton.icon(
            onPressed: () => notifier.setSchritt(state.schritt - 1),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Zurück'),
          ),
      ],
      content: switch (state.schritt) {
        1 => const SchrittModus(),
        2 => const SchrittAuswahl(),
        3 => const SchrittZeitraumOptionen(),
        4 => const SchrittVorschau(),
        _ => const SchrittErgebnis(),
      },
    );
  }
}
