import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../common_widgets/forms/app_text_field.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../billing/domain/models/zahlungsart.dart';
import '../../billing/services/zahlung_service.dart';
import '../data/rechnungen_repository.dart';
import '../domain/models/rechnung_with_details.dart';

/// Dialog zum Stornieren einer Rechnung mit Gutschrift (Credit Note).
///
/// Erzeugt gemäß [`plans/rechnungsstellung-redesign.md`](../../../plans/rechnungsstellung-redesign.md)
/// Kap. 4.4:
/// - Statuswechsel der Originalrechnung auf `storniert` (mit Pflicht-Bemerkung)
/// - Gutschrift als eigener Beleg (`G-YYYY-XXXXX`, negative Beträge)
/// - Negative Zahlung zum Ausgleich bereits geleisteter Zahlungen
class GutschriftDialog extends HookConsumerWidget {
  const GutschriftDialog({super.key, required this.rechnung});

  final RechnungWithDetails rechnung;

  /// Öffnet den Gutschrift-Dialog als modalen Dialog.
  static Future<void> show(BuildContext context, RechnungWithDetails rechnung) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => GutschriftDialog(rechnung: rechnung),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaving = useState(false);
    final grundController = useTextEditingController();
    final currency = NumberFormat.currency(locale: 'de_DE', symbol: '€');

    Future<void> stornieren() async {
      if (grundController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte einen Grund angeben.')),
        );
        return;
      }
      isSaving.value = true;
      try {
        final db = ref.read(appDatabaseProvider);
        final zahlungen = ref.read(zahlungServiceProvider);
        final rechnungenRepo = ref.read(rechnungenRepositoryProvider);

        await db.transaction(() async {
          // 1. Gutschrift als negativer Beleg
          final nummer = await rechnungenRepo.generateRechnungsnummer();
          final gutschriftId = await db
              .into(db.rechnungen)
              .insert(
                RechnungenCompanion.insert(
                  rechnungsnummer: nummer.replaceFirst('R-', 'G-'),
                  mitgliedId: drift.Value(rechnung.rechnung.mitgliedId),
                  kundeName: drift.Value(rechnung.rechnung.kundeName),
                  status: 'bezahlt',
                  datum: DateTime.now(),
                  faelligAm: DateTime.now(),
                  betragNetto: -rechnung.rechnung.betragNetto,
                  betragBrutto: -rechnung.rechnung.betragBrutto,
                  betragMwst: -rechnung.rechnung.betragMwst,
                ),
              );

          // 2. Negative Positionen kopieren
          final positionen = await (db.select(db.rechnungPositionen)
                ..where((p) => p.rechnungId.equals(rechnung.rechnung.id)))
              .get();
          for (var i = 0; i < positionen.length; i++) {
            final p = positionen[i];
            await db
                .into(db.rechnungPositionen)
                .insert(
                  RechnungPositionenCompanion.insert(
                    rechnungId: gutschriftId,
                    positionNr: i + 1,
                    warenId: drift.Value(p.warenId),
                    bezeichnung: p.bezeichnung,
                    menge: drift.Value(-p.menge),
                    einzelpreisNetto: p.einzelpreisNetto,
                    einzelpreisBrutto: p.einzelpreisBrutto,
                    mwstSatz: p.mwstSatz,
                    gesamtNetto: -p.gesamtNetto,
                    gesamtBrutto: -p.gesamtBrutto,
                  ),
                );
          }

          // 3. Originalrechnung stornieren (Status-Historie mit Pflicht-Grund)
          await (db.update(db.rechnungen)
                ..where((r) => r.id.equals(rechnung.rechnung.id)))
              .write(RechnungenCompanion(status: const drift.Value('storniert')));
          await db
              .into(db.rechnungStatusVerlaeufe)
              .insert(
                RechnungStatusVerlaeufeCompanion.insert(
                  rechnungId: rechnung.rechnung.id,
                  status: 'storniert',
                  geaendertAm: DateTime.now(),
                  bemerkung: grundController.text.trim(),
                ),
              );

          // 4. Bereits gezahlte Beträge über negative Zahlung ausgleichen
          final gezahlt = await zahlungen.berechneSaldoRechnung(
            rechnung.rechnung.id,
          );
          final bereitsBezahlt = rechnung.rechnung.betragBrutto - gezahlt;
          if (bereitsBezahlt > 0.005) {
            await zahlungen.bucheZahlungFuerRechnung(
              rechnungId: rechnung.rechnung.id,
              betrag: -bereitsBezahlt,
              zahlungsart: Zahlungsart.sonstiges,
              bemerkung: 'Storno-Ausgleich (Gutschrift ${nummer.replaceFirst('R-', 'G-')})',
            );
          }
        });

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Rechnung ${rechnung.rechnung.rechnungsnummer} storniert – '
                'Gutschrift erstellt.',
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Stornieren: $e')),
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    return AppEditDialogScaffold(
      title: 'Rechnung stornieren – ${rechnung.rechnung.rechnungsnummer}',
      isSaving: isSaving.value,
      contentWidth: 520,
      saveLabel: 'Stornieren + Gutschrift',
      saveIcon: Icons.assignment_return,
      onSave: stornieren,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      'Die Rechnung wird als storniert markiert. Eine Gutschrift '
                      'über ${currency.format(rechnung.rechnung.betragBrutto)} '
                      'wird erstellt. Dieser Vorgang ist nicht umkehrbar.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(16),
          AppTextField(
            controller: grundController,
            label: 'Stornogrund (Pflicht)',
            maxLines: 3,
            required: true,
          ),
        ],
      ),
    );
  }
}
