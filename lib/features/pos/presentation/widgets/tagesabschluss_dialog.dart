import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/pos_repository.dart';

/// Kassenbericht (Tagesabschluss) mit Summen je Zahlart.
class TagesabschlussDialog extends HookConsumerWidget {
  const TagesabschlussDialog({super.key});

  /// Öffnet den Tagesabschluss als modalen Dialog.
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TagesabschlussDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datum = useState(DateTime.now());
    final abschlussAsync = useMemoized(
      () => ref
          .read(posRepositoryProvider)
          .erstelleTagesabschluss(datum: datum.value),
      [datum.value],
    );
    final abschlussSnapshot = useFuture(abschlussAsync);
    final abschluss = abschlussSnapshot.data;
    final dateFormat = DateFormat('dd.MM.yyyy');

    return AppEditDialogScaffold(
      title: 'Tagesabschluss – ${dateFormat.format(datum.value)}',
      isSaving: false,
      contentWidth: 480,
      saveLabel: 'Schließen',
      saveIcon: Icons.check,
      onSave: () => Navigator.of(context).pop(),
      additionalActions: [
        TextButton.icon(
          icon: const Icon(Icons.chevron_left),
          label: const Text('Vortag'),
          onPressed: () => datum.value = datum.value.subtract(
            const Duration(days: 1),
          ),
        ),
        TextButton.icon(
          icon: const Icon(Icons.chevron_right),
          label: const Text('Folgetag'),
          onPressed: () => datum.value = datum.value.add(
            const Duration(days: 1),
          ),
        ),
      ],
      content: abschluss == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Zeile(label: 'Vorgänge', wert: '${abschluss.anzahlVorgaenge}'),
                const Divider(),
                _Zeile(label: 'Bar', wert: formatCurrencyEur(abschluss.summeBar)),
                _Zeile(label: 'Karte', wert: formatCurrencyEur(abschluss.summeKarte)),
                _Zeile(
                  label: 'Kasse gesamt',
                  wert: formatCurrencyEur(abschluss.summeKasse),
                  fett: true,
                ),
                const Divider(),
                _Zeile(
                  label: 'Offene Rechnungen',
                  wert: formatCurrencyEur(abschluss.summeRechnung),
                ),
                _Zeile(
                  label: 'Tagesumsatz gesamt',
                  wert: formatCurrencyEur(abschluss.summeGesamt),
                  fett: true,
                ),
              ],
            ),
    );
  }
}

/// Beschriftete Zeile im Kassenbericht.
class _Zeile extends StatelessWidget {
  const _Zeile({required this.label, required this.wert, this.fett = false});

  final String label;
  final String wert;
  final bool fett;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            wert,
            style: TextStyle(
              fontWeight: fett ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
