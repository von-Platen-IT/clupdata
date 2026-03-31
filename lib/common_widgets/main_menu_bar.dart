import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../features/members/widgets/member_edit_dialog.dart';
import '../features/leistungen/widgets/leistung_edit_dialog.dart';
import '../features/waren/widgets/waren_edit_dialog.dart';
import '../features/beitraege/presentation/dialogs/rechnungslegung_dialog.dart';

class MainMenuBar extends ConsumerWidget {
  const MainMenuBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hier verwenden wir eine einfache AppBar als MenuBar-Ersatz,
    // um die Kompatibilität auf allen OS zu garantieren und es einheitlich zu stylen.
    return Container(
      height: 36, // Klassische Desktop-Menühöhe
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          _MenuButton(
            title: 'Datei',
            items: [
              PopupMenuItem(child: const Text('Einstellungen'), onTap: () {}),
              const PopupMenuDivider(),
              PopupMenuItem(
                child: const Text('Beenden'),
                onTap: () {
                  exit(0);
                },
              ),
            ],
          ),
          _MenuButton(
            title: 'Erstellen',
            items: [
              PopupMenuItem(
                child: const Text('Mitglied'),
                onTap: () {
                  // Dialog zum Hinzufügen eines Mitglieds öffnen
                  MemberEditDialog.show(context);
                },
              ),
              PopupMenuItem(
                child: const Text('Leistung'),
                onTap: () {
                  // Dialog zum Hinzufügen einer Leistung öffnen
                  LeistungEditDialog.show(context);
                },
              ),
              PopupMenuItem(
                child: const Text('Ware'),
                onTap: () {
                  // Dialog zum Hinzufügen einer Ware öffnen
                  WarenEditDialog.show(context);
                },
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                child: const Text('Rechnungslegung'),
                onTap: () {
                  // Dialog zur Massenerstellung von Beiträgen öffnen
                  RechnungslegungDialog.show(context);
                },
              ),
            ],
          ),

          _MenuButton(
            title: 'Hilfe',
            items: [
              PopupMenuItem(
                child: const Text('Über die App'),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'ClupData',
                    applicationVersion: '1.0.0',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String title;
  final List<PopupMenuEntry<dynamic>> items;

  const _MenuButton({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.black12,
      ),
      child: PopupMenuButton(
        offset: const Offset(0, 30),
        tooltip: '',
        itemBuilder: (context) => items,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
