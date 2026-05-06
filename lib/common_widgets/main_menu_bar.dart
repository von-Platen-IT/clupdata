import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/providers/active_menu_item_provider.dart';
import '../core/providers/create_action_provider.dart';
import 'csv_bulk_export_dialog.dart';
import 'csv_bulk_import_dialog.dart';
import 'database_backup_dialog.dart';

/// Einfache Hauptmenüleiste mit Menüpunkten.
///
/// Jedes Menü-Item setzt den aktiven Menüpunkt im [activeMenuItemProvider],
/// der dann im Hauptbereich angezeigt wird.
class MainMenuBar extends ConsumerWidget {
  const MainMenuBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 36,
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
              PopupMenuItem(
                child: const Text('Einstellungen'),
                onTap: () => ref
                    .read(activeMenuItemProvider.notifier)
                    .setActiveItem('Datei > Einstellungen'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(child: const Text('Beenden'), onTap: () => exit(0)),
            ],
          ),
          _MenuButton(
            title: 'Erstellen',
            items: [
              for (final entry in ref.watch(createActionRegistryProvider))
                PopupMenuItem(
                  child: Text(entry.label),
                  onTap: () => ref
                      .read(activeMenuItemProvider.notifier)
                      .setActiveItem('Erstellen > ${entry.label}'),
                ),
            ],
          ),
          _MenuButton(
            title: 'Datenübertragung',
            items: [
              // Import Submenü
              const PopupMenuItem(
                enabled: false,
                height: 32,
                child: Text(
                  'Import',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              PopupMenuItem(
                height: 32,
                padding: const EdgeInsets.only(left: 32),
                child: const Text('CSV Import'),
                onTap: () => showCsvBulkImportDialog(context, ref),
              ),
              PopupMenuItem(
                height: 32,
                padding: const EdgeInsets.only(left: 32),
                child: const Text('Datenbank-Restore'),
                onTap: () => showRestoreDialog(context, ref),
              ),
              const PopupMenuDivider(),
              // Export Submenü
              const PopupMenuItem(
                enabled: false,
                height: 32,
                child: Text(
                  'Export',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              PopupMenuItem(
                height: 32,
                padding: const EdgeInsets.only(left: 32),
                child: const Text('CSV Export'),
                onTap: () => showCsvBulkExportDialog(context, ref),
              ),
              PopupMenuItem(
                height: 32,
                padding: const EdgeInsets.only(left: 32),
                child: const Text('PDF erstellen'),
                onTap: () => ref
                    .read(activeMenuItemProvider.notifier)
                    .setActiveItem('Datenübertragung > Export > PDF erstellen'),
              ),
              PopupMenuItem(
                height: 32,
                padding: const EdgeInsets.only(left: 32),
                child: const Text('Ausdrucken'),
                onTap: () => ref
                    .read(activeMenuItemProvider.notifier)
                    .setActiveItem('Datenübertragung > Export > Ausdrucken'),
              ),
              PopupMenuItem(
                height: 32,
                padding: const EdgeInsets.only(left: 32),
                child: const Text('Datenbank-Backup'),
                onTap: () => showBackupDialog(context, ref),
              ),
            ],
          ),
          _MenuButton(
            title: 'Hilfe',
            items: [
              PopupMenuItem(
                child: const Text('Hilfe & Dokumentation'),
                onTap: () => context.push('/documentation'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                child: const Text('Über die App'),
                onTap: () => ref
                    .read(activeMenuItemProvider.notifier)
                    .setActiveItem('Hilfe > Über die App'),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
