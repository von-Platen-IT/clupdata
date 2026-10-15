import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/utils/currency_formatter.dart';
import '../data/offene_posten_repository.dart';
import '../domain/models/offener_posten.dart';
import '../utils/billing_status_colors.dart';
import 'widgets/mahnlauf_wizard.dart';
import 'widgets/zahlung_eingang_dialog.dart';

/// Offene Posten über beide Belegarten (Beiträge + Waren-Rechnungen).
///
/// Zeigt Saldo, Fälligkeit und Überfälligkeit. Zeilenaktionen:
/// Zahlung erfassen, Mahnen. Aktionen: Mahnlauf starten.
class OffenePostenScreen extends HookConsumerWidget {
  const OffenePostenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nurUeberfaellig = useState(false);
    final postenAsync = useMemoized(
      () => ref
          .read(offenePostenRepositoryProvider)
          .ladeOffenePosten(nurUeberfaellig: nurUeberfaellig.value),
      [nurUeberfaellig.value],
    );
    final postenSnapshot = useFuture(postenAsync);
    final posten = postenSnapshot.data ?? const <OffenerPosten>[];

    final gesamtSaldo = posten.fold<double>(0, (sum, p) => sum + p.saldo);
    final ueberfaelligAnzahl = posten.where((p) => p.istUeberfaellig).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offene Posten'),
        actions: [
          FilterChip(
            label: const Text('Nur überfällig'),
            selected: nurUeberfaellig.value,
            onSelected: (v) => nurUeberfaellig.value = v,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _Kennzahl(
                  label: 'Offene Posten',
                  wert: '${posten.length}',
                ),
                _Kennzahl(
                  label: 'Überfällig',
                  wert: '$ueberfaelligAnzahl',
                ),
                _Kennzahl(
                  label: 'Gesamt offen',
                  wert: formatCurrencyEur(gesamtSaldo),
                ),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.notification_important),
                  label: const Text('Mahnlauf starten'),
                  onPressed: posten.isEmpty
                      ? null
                      : () => MahnlaufWizardDialog.show(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: postenSnapshot.connectionState == ConnectionState.waiting
                ? const Center(child: CircularProgressIndicator())
                : posten.isEmpty
                ? const Center(child: Text('Keine offenen Posten.'))
                : ListView.separated(
                    itemCount: posten.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) => _PostenZeile(
                      posten: posten[index],
                      onZahlung: () async {
                        await ZahlungEingangDialog.show(context, posten[index]);
                        // Liste nach der Buchung neu laden.
                        if (context.mounted) {
                          (context as Element).markNeedsBuild();
                        }
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Zeile eines offenen Postens mit Saldo und Aktionen.
class _PostenZeile extends StatelessWidget {
  const _PostenZeile({required this.posten, required this.onZahlung});

  final OffenerPosten posten;
  final VoidCallback onZahlung;

  @override
  Widget build(BuildContext context) {
    final farbe = BillingStatusColors.forStatus(posten.status);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: farbe ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          posten.belegArt == OffenerPostenArt.beitrag
              ? Icons.card_membership
              : Icons.receipt_long,
          size: 18,
        ),
      ),
      title: Text('${posten.nummer} · ${posten.kundeName ?? posten.bezeichnung}'),
      subtitle: Text(
        'Fällig: ${posten.faelligAm.toString().substring(0, 10)}'
        '${posten.istUeberfaellig ? ' · ${posten.tageUeberfaellig} Tage überfällig' : ''}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCurrencyEur(posten.saldo),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: posten.istUeberfaellig
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onZahlung,
            child: const Text('Zahlung'),
          ),
        ],
      ),
    );
  }
}

/// Kompakte Kennzahl-Anzeige.
class _Kennzahl extends StatelessWidget {
  const _Kennzahl({required this.label, required this.wert});

  final String label;
  final String wert;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(wert, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
