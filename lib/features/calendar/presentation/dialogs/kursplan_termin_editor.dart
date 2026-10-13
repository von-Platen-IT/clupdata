import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

import '../../domain/models/kurs_row_data.dart';
import '../../domain/wochen_utils.dart';

/// Eingabe-Zustand eines Termins im Kursplan-Editor.
///
/// Mutable Felder werden direkt von den Zeilen-Widgets aktualisiert;
/// die feste [id] sichert den Widget-State bei Listenänderungen.
class TerminEingabe {
  static int _naechsteId = 0;

  /// Eindeutige, lokale Identität für Widget-Keys.
  final int id;

  int? kursId;
  int wochentag;
  String startzeit;
  String? endezeit;

  TerminEingabe({
    this.kursId,
    this.wochentag = 1,
    this.startzeit = '18:00',
    this.endezeit,
  }) : id = _naechsteId++;
}

/// Editor für die Kurstermine eines Kursplans.
///
/// Zeilen: Wochentag, Kurs, Start/Ende (`HH:mm`) + Entfernen.
/// Änderungen werden über [onChanged] mitgeteilt (gleiche Listen-Instanzen).
class KursplanTerminEditor extends StatelessWidget {
  final List<TerminEingabe> termine;
  final List<KursRowData> kurse;
  final ValueChanged<List<TerminEingabe>> onChanged;

  const KursplanTerminEditor({
    super.key,
    required this.termine,
    required this.kurse,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Termine', style: Theme.of(context).textTheme.titleMedium),
        const Gap(8),
        if (termine.isEmpty)
          const Text('Noch keine Termine angelegt.')
        else
          for (final termin in termine)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TerminZeile(
                key: ValueKey(termin.id),
                termin: termin,
                kurse: kurse,
                onChanged: () => onChanged(termine),
                onRemove: () {
                  termine.remove(termin);
                  onChanged(termine);
                },
              ),
            ),
        TextButton.icon(
          onPressed: () {
            termine.add(TerminEingabe());
            onChanged(termine);
          },
          icon: const Icon(Icons.add),
          label: const Text('Termin hinzufügen'),
        ),
      ],
    );
  }
}

/// Eine Termin-Zeile mit Wochentag, Kurs und Uhrzeiten.
class _TerminZeile extends HookWidget {
  final TerminEingabe termin;
  final List<KursRowData> kurse;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _TerminZeile({
    super.key,
    required this.termin,
    required this.kurse,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final startController = useTextEditingController(text: termin.startzeit);
    final endeController = useTextEditingController(
      text: termin.endezeit ?? '',
    );

    return Row(
      children: [
        // Wochentag
        SizedBox(
          width: 130,
          child: DropdownButtonFormField<int>(
            value: termin.wochentag,
            decoration: const InputDecoration(
              labelText: 'Tag',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (var i = 0; i < wochentagNamen.length; i++)
                DropdownMenuItem(value: i + 1, child: Text(wochentagNamen[i])),
            ],
            onChanged: (v) {
              if (v != null) {
                termin.wochentag = v;
                onChanged();
              }
            },
          ),
        ),
        const Gap(8),
        // Kurs
        Expanded(
          child: DropdownButtonFormField<int>(
            value: termin.kursId,
            decoration: const InputDecoration(
              labelText: 'Kurs',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final kurs in kurse)
                DropdownMenuItem(value: kurs.id, child: Text(kurs.name)),
            ],
            onChanged: (v) {
              termin.kursId = v;
              onChanged();
            },
          ),
        ),
        const Gap(8),
        // Startzeit
        SizedBox(
          width: 80,
          child: TextField(
            controller: startController,
            decoration: const InputDecoration(
              labelText: 'Von',
              hintText: 'HH:mm',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (t) {
              termin.startzeit = t;
              onChanged();
            },
          ),
        ),
        const Gap(8),
        // Endzeit
        SizedBox(
          width: 80,
          child: TextField(
            controller: endeController,
            decoration: const InputDecoration(
              labelText: 'Bis',
              hintText: 'HH:mm',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (t) {
              termin.endezeit = t.trim().isEmpty ? null : t;
              onChanged();
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Termin entfernen',
          onPressed: onRemove,
        ),
      ],
    );
  }
}
