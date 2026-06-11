import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../core/keyboard/keyboard_shortcuts.dart';
import '../core/providers/active_menu_item_provider.dart';
import '../features/rechnungserstellung/presentation/dialogs/beitraege_batch_dialog.dart';
import '../features/beitraege/presentation/dialogs/neuer_beitrag_dialog.dart';
import '../features/rechnungen/widgets/neue_rechnung_dialog.dart';
import '../features/members/widgets/member_edit_dialog.dart';
import '../features/leistungen/widgets/leistung_edit_dialog.dart';
import '../features/waren/widgets/waren_edit_dialog.dart';
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
                child: _MenuItemWithShortcut(
                  label: 'Einstellungen',
                  shortcut: MenuShortcuts.settings.menuLabel,
                ),
                onTap: () => context.push('/master-data'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                child: _MenuItemWithShortcut(
                  label: 'Beenden',
                  shortcut: MenuShortcuts.quit.menuLabel,
                ),
                onTap: () => exit(0),
              ),
            ],
          ),
          _MenuButton(
            title: 'Erstellen',
            items: [
              // Stammdaten
              PopupMenuItem(
                child: _MenuItemWithShortcut(
                  label: 'Neues Mitglied',
                  shortcut: MenuShortcuts.createMitglied.menuLabel,
                ),
                onTap: () => MemberEditDialog.show(context),
              ),
              PopupMenuItem(
                child: _MenuItemWithShortcut(
                  label: 'Neue Leistung',
                  shortcut: MenuShortcuts.createLeistung.menuLabel,
                ),
                onTap: () => LeistungEditDialog.show(context),
              ),
              const PopupMenuDivider(),
              // Finanzen
              PopupMenuItem(
                child: _MenuItemWithShortcut(
                  label: 'Neuer Beitrag',
                  shortcut: MenuShortcuts.createBeitrag.menuLabel,
                ),
                onTap: () => NeuerBeitragDialog.show(context),
              ),
              PopupMenuItem(
                child: _MenuItemWithShortcut(
                  label: 'Neue Rechnung',
                  shortcut: MenuShortcuts.createRechnung.menuLabel,
                ),
                onTap: () => NeueRechnungDialog.show(context),
              ),
              PopupMenuItem(
                child: _MenuItemWithShortcut(
                  label: 'Neue Ware',
                  shortcut: MenuShortcuts.createWare.menuLabel,
                ),
                onTap: () => WarenEditDialog.show(context),
              ),
            ],
          ),
          _MenuButton(
            title: 'Extras',
            items: [
              // Rechnungserstellung Submenü
              const PopupMenuItem(
                enabled: false,
                height: 32,
                child: Text(
                  'Rechnungserstellung',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              PopupMenuItem(
                height: 32,
                padding: const EdgeInsets.only(left: 32),
                child: _MenuItemWithShortcut(
                  label: 'Beiträge',
                  shortcut: MenuShortcuts.rechnungBeitraege.menuLabel,
                ),
                onTap: () => BeitraegeBatchDialog.show(context),
              ),
              const PopupMenuDivider(),
              // Datenbank Submenü
              const PopupMenuItem(
                enabled: false,
                height: 32,
                child: Text(
                  'Datenbank',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              PopupMenuItem(
                height: 32,
                padding: const EdgeInsets.only(left: 32),
                child: _MenuItemWithShortcut(
                  label: 'Backup',
                  shortcut: MenuShortcuts.backup.menuLabel,
                ),
                onTap: () => showBackupDialog(context, ref),
              ),
              PopupMenuItem(
                height: 32,
                padding: const EdgeInsets.only(left: 32),
                child: _MenuItemWithShortcut(
                  label: 'Restore',
                  shortcut: MenuShortcuts.restore.menuLabel,
                ),
                onTap: () => showRestoreDialog(context, ref),
              ),
              const PopupMenuDivider(),
              // CSV Dateien Submenü
              const PopupMenuItem(
                enabled: false,
                height: 32,
                child: Text(
                  'CSV Dateien',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              PopupMenuItem(
                height: 32,
                padding: const EdgeInsets.only(left: 32),
                child: _MenuItemWithShortcut(
                  label: 'Exportieren',
                  shortcut: MenuShortcuts.csvExport.menuLabel,
                ),
                onTap: () => showCsvBulkExportDialog(context, ref),
              ),
              PopupMenuItem(
                height: 32,
                padding: const EdgeInsets.only(left: 32),
                child: _MenuItemWithShortcut(
                  label: 'Importieren',
                  shortcut: MenuShortcuts.csvImport.menuLabel,
                ),
                onTap: () => showCsvBulkImportDialog(context, ref),
              ),
            ],
          ),
          _MenuButton(
            title: 'Hilfe',
            items: [
              PopupMenuItem(
                child: _MenuItemWithShortcut(
                  label: 'Hilfe & Dokumentation',
                  shortcut: MenuShortcuts.help.menuLabel,
                ),
                onTap: () => context.push('/documentation'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                child: _MenuItemWithShortcut(
                  label: 'Über die App',
                  shortcut: MenuShortcuts.about.menuLabel,
                ),
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

/// Widget für Menüeinträge mit Shortcut-Anzeige.
class _MenuItemWithShortcut extends StatelessWidget {
  final String label;
  final String shortcut;

  const _MenuItemWithShortcut({required this.label, required this.shortcut});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label),
        const Spacer(),
        Text(
          shortcut,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
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
