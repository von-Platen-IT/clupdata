import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../../common_widgets/forms/app_text_field.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/models/offener_posten.dart';
import '../../domain/models/zahlungsart.dart';
import '../../services/zahlung_service.dart';

/// Dialog zur Erfassung eines Zahlungseingangs (Voll- oder Teilzahlung).
///
/// Zeigt den offenen Saldo, akzeptiert beliebige Beträge bis zur vollen
/// Forderung und löst über den [`ZahlungService`] die Status-Kaskade aus
/// (`teilbezahlt` bzw. `bezahlt`).
class ZahlungEingangDialog extends HookConsumerWidget {
  const ZahlungEingangDialog({super.key, required this.posten});

  final OffenerPosten posten;

  /// Öffnet den Dialog als modalen Dialog.
  static Future<void> show(BuildContext context, OffenerPosten posten) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ZahlungEingangDialog(posten: posten),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaving = useState(false);
    final betragController = useTextEditingController(
      text: posten.saldo.toStringAsFixed(2),
    );
    final bemerkungController = useTextEditingController();
    final zahlungsart = useState(Zahlungsart.ueberweisung);
    final datum = useState(DateTime.now());
    final betragFehler = useState<String?>(null);

    Future<void> buchen() async {
      final betrag =
          double.tryParse(betragController.text.replaceAll(',', '.')) ?? 0;
      if (betrag <= 0) {
        betragFehler.value = 'Bitte einen Betrag größer 0 eingeben.';
        return;
      }
      if (betrag > posten.saldo + 0.005) {
        betragFehler.value = 'Der Betrag übersteigt den offenen Saldo '
            '(${formatCurrencyEur(posten.saldo)}).';
        return;
      }

      isSaving.value = true;
      try {
        final service = ref.read(zahlungServiceProvider);
        final ZahlungBuchungResult ergebnis;
        if (posten.belegArt == OffenerPostenArt.beitrag) {
          ergebnis = await service.bucheZahlungFuerBeitrag(
            beitragId: posten.belegId,
            betrag: betrag,
            zahlungsart: zahlungsart.value,
            datum: datum.value,
            bemerkung: bemerkungController.text.isEmpty
                ? null
                : bemerkungController.text,
          );
        } else {
          ergebnis = await service.bucheZahlungFuerRechnung(
            rechnungId: posten.belegId,
            betrag: betrag,
            zahlungsart: zahlungsart.value,
            datum: datum.value,
            bemerkung: bemerkungController.text.isEmpty
                ? null
                : bemerkungController.text,
          );
        }

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ergebnis.istVollstaendigBezahlt
                    ? 'Zahlung gebucht – vollständig bezahlt.'
                    : 'Teilzahlung gebucht – Rest: '
                          '${formatCurrencyEur(ergebnis.saldo)}',
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Buchen: $e')),
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    return AppEditDialogScaffold(
      title: 'Zahlung erfassen – ${posten.nummer}',
      isSaving: isSaving.value,
      contentWidth: 520,
      saveLabel: 'Zahlung buchen',
      saveIcon: Icons.payments,
      onSave: buchen,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${posten.belegArt.label} · ${posten.kundeName ?? ''}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    'Offen: ${formatCurrencyEur(posten.saldo)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const Gap(16),
          AppTextField(
            controller: betragController,
            label: 'Zahlbetrag (€)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            errorText: betragFehler.value,
            onChanged: (_) => betragFehler.value = null,
          ),
          const Gap(12),
          Row(
            children: [
              const Text('Datum:'),
              const Gap(8),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(DateFormat('dd.MM.yyyy').format(datum.value)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: datum.value,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) datum.value = d;
                },
              ),
            ],
          ),
          const Gap(12),
          Text('Zahlart', style: Theme.of(context).textTheme.titleSmall),
          const Gap(4),
          Wrap(
            spacing: 8,
            children: [
              for (final art in Zahlungsart.values)
                ChoiceChip(
                  label: Text(art.label),
                  selected: zahlungsart.value == art,
                  onSelected: (_) => zahlungsart.value = art,
                ),
            ],
          ),
          const Gap(12),
          AppTextField(
            controller: bemerkungController,
            label: 'Bemerkung (optional)',
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
