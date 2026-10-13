import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../domain/models/schnellerfassung_felder.dart';
import '../services/schnellerfassung_service.dart';
import 'providers/schnellerfassung_providers.dart';
import 'widgets/erfasste_liste.dart';
import 'widgets/mitglied_schnell_formular.dart';
import 'widgets/vorlage_leiste.dart';

/// Schnellerfassung – Eingabe-Arbeitsbereich für Massenerfassungen.
///
/// Optimiert für die Erstbefüllung: „Speichern & weiter" mit Auto-Vorlage,
/// benannte Vorlagen, Übernahme vorhandener Datensätze, Duplikat-Warnung
/// und Sitzungs-Protokoll. Siehe `plans/schnellerfassung.md`.
class SchnellerfassungScreen extends HookConsumerWidget {
  const SchnellerfassungScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final felder = useState(SchnellerfassungFelder.leer);
    final formVersion = useState(0);
    final isSaving = useState(false);

    // Duplikat-Warnung (debounced, informativ – blockiert nicht).
    useEffect(() {
      final name = felder.value.name.trim();
      final vorname = felder.value.vorname.trim();
      if (name.isEmpty) {
        // Verzögert, um Provider-Änderungen während des Widget-Builds
        // zu vermeiden (Riverpod-Fehler: „modify a provider while building").
        Future(
          () => ref.read(sitzungsProtokollProvider.notifier).setzeWarnung(null),
        );
        return null;
      }
      final timer = Timer(const Duration(milliseconds: 500), () {
        final protokoll = ref.read(sitzungsProtokollProvider);
        ref
            .read(schnellerfassungServiceProvider)
            .istMoeglichesDuplikat(
              name: name,
              vorname: vorname,
              sitzungsnamen: protokoll.namen,
            )
            .then((duplikat) {
              ref
                  .read(sitzungsProtokollProvider.notifier)
                  .setzeWarnung(
                    duplikat
                        ? 'Möglicher Duplikat: „$name, $vorname" wurde bereits '
                              'erfasst.'
                        : null,
                  );
            });
      });
      return timer.cancel;
    }, [felder.value.name, felder.value.vorname]);

    void setzeFelder(SchnellerfassungFelder neu) {
      felder.value = neu;
      formVersion.value++;
    }

    Future<void> speichern({required bool felderBehalten}) async {
      final f = felder.value;
      if (f.name.trim().isEmpty ||
          f.vorname.trim().isEmpty ||
          f.leistungId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte Name, Vorname und Leistung ausfüllen.'),
          ),
        );
        return;
      }

      isSaving.value = true;
      try {
        final service = ref.read(schnellerfassungServiceProvider);
        await service.speichereMitglied(f);
        ref
            .read(sitzungsProtokollProvider.notifier)
            .fuegeHinzu('${f.name.trim()}, ${f.vorname.trim()}');
        ref.read(sitzungsProtokollProvider.notifier).setzeWarnung(null);
        setzeFelder(
          felderBehalten ? f.alsNaechsteVorlage() : SchnellerfassungFelder.leer,
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Speichern: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        isSaving.value = false;
      }
    }

    return CallbackShortcuts(
      bindings: {
        // Strg+Enter = Speichern & leeren (schneller Tastatur-Workflow)
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
            speichern(felderBehalten: false),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(title: const Text('Schnellerfassung – Mitglieder')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VorlageLeiste(
                  aktuelleFelder: felder.value,
                  onFelderUebernehmen: setzeFelder,
                ),
                const Gap(16),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Eingabeformular
                      Expanded(
                        child: SingleChildScrollView(
                          child: MitgliedSchnellFormular(
                            key: ValueKey(formVersion.value),
                            initial: felder.value,
                            onChanged: (f) => felder.value = f,
                          ),
                        ),
                      ),
                      const Gap(16),
                      // Sitzungs-Protokoll
                      const SizedBox(width: 280, child: ErfassteListe()),
                    ],
                  ),
                ),
                const Gap(12),
                // Aktionsleiste
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: isSaving.value
                          ? null
                          : () => speichern(felderBehalten: false),
                      icon: const Icon(Icons.save),
                      label: const Text('Speichern & leeren  (Strg+Enter)'),
                    ),
                    const Gap(12),
                    OutlinedButton.icon(
                      onPressed: isSaving.value
                          ? null
                          : () => speichern(felderBehalten: true),
                      icon: const Icon(Icons.copy_all),
                      label: const Text('Speichern & Felder behalten'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
