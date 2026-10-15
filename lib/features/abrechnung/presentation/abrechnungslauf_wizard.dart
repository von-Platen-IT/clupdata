import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../common_widgets/app_edit_dialog_scaffold.dart';
import 'providers/abrechnungslauf_provider.dart';
import 'steps/schritt_ergebnis.dart';
import 'steps/schritt_freigabe.dart';
import 'steps/schritt_lauf.dart';
import 'steps/schritt_vorschau.dart';

/// Abrechnungslauf-Assistent (4 Schritte) für die Beitrags-Rechnungsstellung.
///
/// Ersetzt den früheren 5-Schritt-Wizard des `rechnungserstellung`-Features.
/// Ablauf: 1. Empfängerkreis + Zeitraum → 2. Vorschau (editierbar) →
/// 3. Freigabe → 4. Ergebnis & Anschlussaktionen.
///
/// **Einstiegspunkte**:
/// - Menü: Extras → Rechnungserstellung
/// - Tastenkürzel/Toolbar: `MenuShortcuts.rechnungBeitraege`
/// - Beiträge → Neu → „Rechnungslegung"
class AbrechnungslaufWizardDialog extends HookConsumerWidget {
  const AbrechnungslaufWizardDialog({super.key});

  /// Öffnet den Wizard als modalen Dialog.
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AbrechnungslaufWizardDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(abrechnungslaufProvider);
    final notifier = ref.read(abrechnungslaufProvider.notifier);
    final isProcessing = useState(false);

    Future<void> runGuarded(Future<void> Function() action) async {
      isProcessing.value = true;
      try {
        await action();
      } finally {
        isProcessing.value = false;
      }
    }

    return AppEditDialogScaffold(
      title: 'Beiträge abrechnen – Schritt ${state.schritt} von 4',
      isSaving: isProcessing.value,
      contentWidth: 960,
      saveLabel: switch (state.schritt) {
        1 => 'Vorschau berechnen',
        2 => 'Zur Freigabe',
        3 => '${state.zuErstellenAnzahl} Beiträge erstellen',
        _ => 'Schließen',
      },
      saveIcon: switch (state.schritt) {
        1 => Icons.calculate,
        2 => Icons.arrow_forward,
        3 => Icons.play_arrow,
        _ => Icons.check,
      },
      isSaveEnabled: switch (state.schritt) {
        1 => !isProcessing.value,
        2 => state.zuErstellenAnzahl > 0,
        3 => state.zuErstellenAnzahl > 0,
        _ => true,
      },
      onSave: () async {
        switch (state.schritt) {
          case 1:
            await runGuarded(notifier.ladeVorschau);
          case 2:
            notifier.naechsterSchritt();
          case 3:
            await runGuarded(notifier.fuehreAus);
          case 4:
            if (context.mounted) Navigator.of(context).pop();
        }
      },
      additionalActions: [
        if (state.schritt > 1 && state.schritt < 4)
          TextButton(
            onPressed: isProcessing.value ? null : notifier.vorherigerSchritt,
            child: const Text('Zurück'),
          ),
      ],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SchrittAnzeige(aktuellerSchritt: state.schritt),
          const Divider(height: 24),
          switch (state.schritt) {
            1 => const SchrittLauf(),
            2 => const SchrittVorschau(),
            3 => const SchrittFreigabe(),
            _ => const SchrittErgebnis(),
          },
        ],
      ),
    );
  }
}

/// Kompakte Schritt-Anzeige (1–4) über dem Wizard-Inhalt.
class _SchrittAnzeige extends StatelessWidget {
  const _SchrittAnzeige({required this.aktuellerSchritt});

  final int aktuellerSchritt;

  static const _labels = ['Lauf', 'Vorschau', 'Freigabe', 'Ergebnis'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          CircleAvatar(
            radius: 14,
            backgroundColor: i < aktuellerSchritt
                ? theme.colorScheme.primary
                : i == aktuellerSchritt - 1
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest,
            foregroundColor: i < aktuellerSchritt
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            child: i < aktuellerSchritt
                ? const Icon(Icons.check, size: 16)
                : Text('${i + 1}', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          Text(
            _labels[i],
            style: TextStyle(
              fontWeight: i == aktuellerSchritt - 1
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          if (i < _labels.length - 1)
            const Expanded(
              child: Divider(indent: 8, endIndent: 8),
            ),
        ],
      ],
    );
  }
}
