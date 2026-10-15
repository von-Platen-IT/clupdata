import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common_widgets/app_edit_dialog_scaffold.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../services/mahnung_service.dart';

/// Mahnlauf-Assistent (2 Schritte): Vorschläge auswählen → Mahnungen erstellen.
///
/// Ermittelt für überfällige offene Posten die nächste Mahnstufe
/// (Fristen 7/14/21 Tage, siehe [`Mahnkonfiguration`] bzw. ADR-006) und
/// dokumentiert den Lauf in [`mahnung`](../../../../assets/data/structur.md).
class MahnlaufWizardDialog extends HookConsumerWidget {
  const MahnlaufWizardDialog({super.key});

  /// Öffnet den Mahnlauf als modalen Dialog.
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MahnlaufWizardDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isProcessing = useState(false);
    final schritt = useState(1);
    final vorschlaege = useState<List<Mahnvorschlag>>(const []);
    final auswahl = useState<Set<int>>({});
    final ergebnis = useState<MahnlaufResult?>(null);

    // Vorschläge beim Öffnen laden (Schritt 1).
    useEffect(() {
      Future<void> laden() async {
        final service = ref.read(mahnungServiceProvider);
        final v = await service.berechneMahnvorschlaege();
        vorschlaege.value = v;
        auswahl.value = {for (var i = 0; i < v.length; i++) i};
      }

      laden();
      return null;
    }, []);

    Future<void> erstellen() async {
      isProcessing.value = true;
      try {
        final service = ref.read(mahnungServiceProvider);
        final gewaehlt = [
          for (final i in auswahl.value) vorschlaege.value[i],
        ];
        final result = await service.erstelleMahnlauf(gewaehlt);
        ergebnis.value = result;
        schritt.value = 2;
      } finally {
        isProcessing.value = false;
      }
    }

    return AppEditDialogScaffold(
      title: schritt.value == 1
          ? 'Mahnlauf – Überfällige auswählen'
          : 'Mahnlauf – Ergebnis',
      isSaving: isProcessing.value,
      contentWidth: 720,
      saveLabel: schritt.value == 1
          ? '${auswahl.value.length} Mahnungen erstellen'
          : 'Schließen',
      saveIcon: schritt.value == 1 ? Icons.notification_important : Icons.check,
      isSaveEnabled: schritt.value == 1 ? auswahl.value.isNotEmpty : true,
      onSave: () async {
        if (schritt.value == 1) {
          await erstellen();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      additionalActions: [
        if (schritt.value == 1)
          TextButton(
            onPressed: isProcessing.value ? null : () => auswahl.value = {},
            child: const Text('Alle abwählen'),
          ),
      ],
      content: schritt.value == 1
          ? _SchrittAuswahl(
              vorschlaege: vorschlaege.value,
              auswahl: auswahl.value,
              onToggle: (i) {
                final neue = Set<int>.from(auswahl.value);
                neue.contains(i) ? neue.remove(i) : neue.add(i);
                auswahl.value = neue;
              },
            )
          : _SchrittErgebnis(ergebnis: ergebnis.value),
    );
  }
}

/// Schritt 1: Liste der Mahnvorschläge mit Checkboxen.
class _SchrittAuswahl extends StatelessWidget {
  const _SchrittAuswahl({
    required this.vorschlaege,
    required this.auswahl,
    required this.onToggle,
  });

  final List<Mahnvorschlag> vorschlaege;
  final Set<int> auswahl;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    if (vorschlaege.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Keine überfälligen Posten für einen Mahnlauf gefunden.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nächste Mahnstufe gemäß Fristenregel (7 / 14 / 21 Tage).',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Gap(8),
        SizedBox(
          height: 320,
          child: ListView.builder(
            itemCount: vorschlaege.length,
            itemBuilder: (context, i) {
              final v = vorschlaege[i];
              return CheckboxListTile(
                value: auswahl.contains(i),
                onChanged: (_) => onToggle(i),
                title: Text(
                  '${v.posten.nummer} · ${v.posten.kundeName ?? ''}',
                ),
                subtitle: Text(
                  '${v.stufeLabel} · seit ${v.posten.tageUeberfaellig} Tagen '
                  'überfällig · Forderung ${formatCurrencyEur(v.forderung)}',
                ),
                secondary: Text(
                  v.gebuehr > 0 ? '+${formatCurrencyEur(v.gebuehr)}' : '–',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Schritt 2: Ergebnis des Mahnlaufs.
class _SchrittErgebnis extends StatelessWidget {
  const _SchrittErgebnis({required this.ergebnis});

  final MahnlaufResult? ergebnis;

  @override
  Widget build(BuildContext context) {
    final e = ergebnis;
    if (e == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              e.fehler.isEmpty ? Icons.check_circle : Icons.warning,
              size: 36,
              color: e.fehler.isEmpty ? Colors.green : Colors.orange,
            ),
            const Gap(12),
            Text(
              '${e.erstellteMahnungen.length} Mahnungen erstellt',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        const Gap(12),
        Text('Gebühren gesamt: ${formatCurrencyEur(e.gesamtGebuehr)}'),
        if (e.fehler.isNotEmpty) ...[
          const Gap(8),
          Text('Fehler:', style: Theme.of(context).textTheme.titleSmall),
          for (final f in e.fehler.take(5)) Text('• $f'),
        ],
        const Gap(12),
        const Text(
          'Die Mahnschreiben stehen als PDF zur Ausgabe bereit '
          '(PDF-Generierung in Phase 5 des Redesign-Plans).',
        ),
      ],
    );
  }
}
