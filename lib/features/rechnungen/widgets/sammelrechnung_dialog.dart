import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/datum_utils.dart';
import '../../members/data/members_repository.dart';
import '../data/rechnungen_repository.dart';

/// Dialog zur Sammelrechnung: mehrere offene Rechnungen eines Mitglieds
/// werden zu einer neuen Rechnung gebündelt.
///
/// Die Einzelrechnungen werden anschließend als `storniert` markiert
/// (mit Status-Historie). Ersetzt den nie implementierten Dialog 2 aus
/// [`plans/rechnungbatch.md`](../../../plans/rechnungbatch.md).
class SammelrechnungDialog extends HookConsumerWidget {
  const SammelrechnungDialog({super.key});

  /// Öffnet den Sammelrechnungs-Dialog als modalen Dialog.
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SammelrechnungDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaving = useState(false);
    final mitglied = useState<Mitglied?>(null);
    final auswahl = useState<Set<int>>({});
    final offeneRechnungen = useState<List<Rechnung>>(const []);
    final currency = NumberFormat.currency(locale: 'de_DE', symbol: '€');

    Future<void> ladeOffene(Mitglied m) async {
      final db = ref.read(appDatabaseProvider);
      final rows =
          await (db.select(db.rechnungen)..where(
                (r) =>
                    r.mitgliedId.equals(m.id) &
                    r.status.isIn(['offen', 'teilbezahlt']),
              ))
              .get();
      offeneRechnungen.value = rows;
      auswahl.value = {for (final r in rows) r.id};
    }

    Future<void> erstellen() async {
      final gewaehlt = offeneRechnungen.value
          .where((r) => auswahl.value.contains(r.id))
          .toList();
      if (gewaehlt.isEmpty) return;

      isSaving.value = true;
      try {
        final db = ref.read(appDatabaseProvider);
        final repo = ref.read(rechnungenRepositoryProvider);
        final nummer = await repo.generateRechnungsnummer();

        await db.transaction(() async {
          // Positionen aller ausgewählten Rechnungen zusammenführen.
          final allePositionen = <RechnungPositionenCompanion>[];
          var summeBrutto = 0.0;
          var summeNetto = 0.0;
          var summeMwst = 0.0;
          for (final r in gewaehlt) {
            final positionen = await (db.select(
              db.rechnungPositionen,
            )..where((p) => p.rechnungId.equals(r.id))).get();
            for (final p in positionen) {
              allePositionen.add(
                RechnungPositionenCompanion(
                  warenId: drift.Value(p.warenId),
                  bezeichnung: drift.Value(p.bezeichnung),
                  menge: drift.Value(p.menge),
                  einzelpreisNetto: drift.Value(p.einzelpreisNetto),
                  einzelpreisBrutto: drift.Value(p.einzelpreisBrutto),
                  mwstSatz: drift.Value(p.mwstSatz),
                  gesamtNetto: drift.Value(p.gesamtNetto),
                  gesamtBrutto: drift.Value(p.gesamtBrutto),
                ),
              );
            }
            summeBrutto += r.betragBrutto;
            summeNetto += r.betragNetto;
            summeMwst += r.betragMwst;
          }

          // Sammelrechnung anlegen.
          await repo.addRechnung(
            RechnungenCompanion.insert(
              rechnungsnummer: nummer,
              mitgliedId: drift.Value(mitglied.value!.id),
              kundeName: drift.Value(
                '${mitglied.value!.name}, ${mitglied.value!.vorname}',
              ),
              status: 'offen',
              datum: DateTime.now(),
              faelligAm: addiereTage(DateTime.now(), 14),
              betragNetto: summeNetto,
              betragBrutto: summeBrutto,
              betragMwst: summeMwst,
            ),
            allePositionen,
          );

          // Einzelrechnungen stornieren (Status-Historie mit Pflicht-Bemerkung).
          for (final r in gewaehlt) {
            await (db.update(
              db.rechnungen,
            )..where((x) => x.id.equals(r.id))).write(
              const RechnungenCompanion(status: drift.Value('storniert')),
            );
            await db
                .into(db.rechnungStatusVerlaeufe)
                .insert(
                  RechnungStatusVerlaeufeCompanion.insert(
                    rechnungId: r.id,
                    status: 'storniert',
                    geaendertAm: DateTime.now(),
                    bemerkung: 'In Sammelrechnung $nummer überführt',
                  ),
                );
          }
        });

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sammelrechnung $nummer erstellt – '
                '${gewaehlt.length} Einzelrechnungen storniert.',
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
        }
      } finally {
        isSaving.value = false;
      }
    }

    final summe = offeneRechnungen.value
        .where((r) => auswahl.value.contains(r.id))
        .fold<double>(0, (s, r) => s + r.betragBrutto);

    return AppEditDialogScaffold(
      title: 'Sammelrechnung erstellen',
      isSaving: isSaving.value,
      contentWidth: 640,
      saveLabel: 'Sammelrechnung erstellen',
      saveIcon: Icons.merge_type,
      isSaveEnabled: auswahl.value.isNotEmpty,
      onSave: erstellen,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Autocomplete<Mitglied>(
            displayStringForOption: (m) => '${m.name}, ${m.vorname}',
            optionsBuilder: (textEditingValue) async {
              if (textEditingValue.text.length < 2) return const [];
              final repo = ref.read(membersRepositoryProvider);
              return repo.searchMembers(textEditingValue.text);
            },
            onSelected: (m) {
              mitglied.value = m;
              ladeOffene(m);
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Mitglied suchen',
                  border: OutlineInputBorder(),
                ),
              );
            },
          ),
          const Gap(16),
          if (mitglied.value == null)
            const Text('Bitte ein Mitglied auswählen.')
          else if (offeneRechnungen.value.isEmpty)
            const Text('Keine offenen Rechnungen für dieses Mitglied.')
          else ...[
            Text(
              'Offene Rechnungen auswählen:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Gap(8),
            SizedBox(
              height: 260,
              child: ListView.builder(
                itemCount: offeneRechnungen.value.length,
                itemBuilder: (context, index) {
                  final r = offeneRechnungen.value[index];
                  return CheckboxListTile(
                    value: auswahl.value.contains(r.id),
                    onChanged: (v) {
                      final neu = Set<int>.from(auswahl.value);
                      v == true ? neu.add(r.id) : neu.remove(r.id);
                      auswahl.value = neu;
                    },
                    title: Text(r.rechnungsnummer),
                    subtitle: Text(DateFormat('dd.MM.yyyy').format(r.datum)),
                    secondary: Text(currency.format(r.betragBrutto)),
                  );
                },
              ),
            ),
            const Gap(8),
            Row(
              children: [
                Text(
                  'Summe: ${currency.format(summe)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text('${auswahl.value.length} Rechnungen ausgewählt'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
