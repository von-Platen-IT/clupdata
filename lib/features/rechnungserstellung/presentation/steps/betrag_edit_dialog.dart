import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../../common_widgets/forms/app_text_field.dart';
import '../providers/rechnungslegung_wizard_provider.dart';

/// Kleiner Dialog zum Überschreiben des Betrags einer Vorschauzeile.
///
/// Der überschriebene Betrag wird als Preis-Snapshot übernommen.
class BetragEditDialog extends HookConsumerWidget {
  final int index;
  final double initialBetrag;

  const BetragEditDialog({
    super.key,
    required this.index,
    required this.initialBetrag,
  });

  /// Opens the dialog for preview row [index].
  static Future<void> show(
    BuildContext context, {
    required int index,
    required double initialBetrag,
  }) {
    return showDialog(
      context: context,
      builder: (_) =>
          BetragEditDialog(index: index, initialBetrag: initialBetrag),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController(
      text: initialBetrag.toStringAsFixed(2).replaceAll('.', ','),
    );

    void speichern() {
      final text = controller.text
          .trim()
          .replaceAll('.', '')
          .replaceAll(',', '.');
      final betrag = double.tryParse(text);
      if (betrag != null) {
        ref
            .read(rechnungslegungWizardProvider.notifier)
            .setZeileBetrag(index, betrag);
      }
      Navigator.of(context).pop();
    }

    return AppEditDialogScaffold(
      title: 'Betrag überschreiben',
      contentWidth: 300,
      isSaving: false,
      onSave: speichern,
      content: AppTextField(
        controller: controller,
        label: 'Betrag (Brutto €)',
        required: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    );
  }
}
