import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mdi/mdi.dart';
import 'package:gap/gap.dart';
import '../core/keyboard/keyboard_shortcuts.dart';
import '../core/providers/active_menu_item_provider.dart';
import '../core/utils/app_version.dart';
import '../features/rechnungserstellung/presentation/dialogs/beitraege_batch_dialog.dart';
import '../features/beitraege/presentation/dialogs/neuer_beitrag_dialog.dart';
import '../features/rechnungen/widgets/neue_rechnung_dialog.dart';
import '../features/members/widgets/member_edit_dialog.dart';
import '../features/leistungen/widgets/leistung_edit_dialog.dart';
import '../features/waren/widgets/waren_edit_dialog.dart';
import 'csv_bulk_export_dialog.dart';
import 'csv_bulk_import_dialog.dart';
import 'database_backup_dialog.dart';
import 'main_menu_bar.dart';

/// Haupt-Layout der Anwendung mit Menüleiste und NavigationRail.
///
/// Wenn ein Menüpunkt ausgewählt wird, wird der gesamte Hauptbereich
/// durch den Text des Menüpunkts ersetzt. Navigation durch die Rail
/// setzt die Auswahl zurück.
class AppShell extends HookConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isExtended = useState(isDesktop);
    final activeMenuItem = ref.watch(activeMenuItemProvider);

    useEffect(() {
      isExtended.value = isDesktop;
      return null;
    }, [isDesktop]);

    void onItemTapped(int index) {
      // Navigation setzt Menü-Auswahl zurück
      ref.read(activeMenuItemProvider.notifier).clear();
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    return CallbackShortcuts(
      bindings: {
        // Datei-Menü
        MenuShortcuts.settings: () => context.push('/master-data'),
        MenuShortcuts.quit: () => exit(0),
        // Erstellen-Menü (Shift + Ctrl/⌘ + Buchstabe) - öffnet direkt den "Neu"-Dialog
        MenuShortcuts.createBeitrag: () => NeuerBeitragDialog.show(context),
        MenuShortcuts.createRechnung: () => NeueRechnungDialog.show(context),
        MenuShortcuts.createMitglied: () => MemberEditDialog.show(context),
        MenuShortcuts.createLeistung: () => LeistungEditDialog.show(context),
        MenuShortcuts.createWare: () => WarenEditDialog.show(context),
        // Rechnungserstellung
        MenuShortcuts.rechnungBeitraege: () =>
            BeitraegeBatchDialog.show(context),
        MenuShortcuts.backup: () => showBackupDialog(context, ref),
        MenuShortcuts.restore: () => showRestoreDialog(context, ref),
        MenuShortcuts.csvExport: () => showCsvBulkExportDialog(context, ref),
        MenuShortcuts.csvImport: () => showCsvBulkImportDialog(context, ref),
        // Hilfe-Menü
        MenuShortcuts.help: () => context.push('/documentation'),
        MenuShortcuts.about: () => ref
            .read(activeMenuItemProvider.notifier)
            .setActiveItem('Hilfe > Über die App'),
        // Navigation (Alt + 1-7)
        MenuShortcuts.dashboard(1): () => onItemTapped(0),
        MenuShortcuts.dashboard(2): () => onItemTapped(1),
        MenuShortcuts.dashboard(3): () => onItemTapped(2),
        MenuShortcuts.dashboard(4): () => onItemTapped(3),
        MenuShortcuts.dashboard(5): () => onItemTapped(4),
        MenuShortcuts.dashboard(6): () => onItemTapped(5),
        MenuShortcuts.dashboard(7): () => onItemTapped(6),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              const MainMenuBar(),
              Expanded(
                child: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: onItemTapped,
                      labelType: isExtended.value
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      extended: isExtended.value,
                      leading: _buildLeading(context, isExtended),
                      trailing: _buildTrailing(context),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Mdi.homeOutline),
                          selectedIcon: Icon(Mdi.home),
                          label: Text('Start'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Mdi.accountGroupOutline),
                          selectedIcon: Icon(Mdi.accountGroup),
                          label: Text('Mitglieder'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Mdi.fileDocumentOutline),
                          selectedIcon: Icon(Mdi.fileDocument),
                          label: Text('Leistungen'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Mdi.cashMultiple),
                          selectedIcon: Icon(Mdi.cashMultiple),
                          label: Text('Beiträge'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.receipt_long_outlined),
                          selectedIcon: Icon(Icons.receipt_long),
                          label: Text('Rechnungen'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Mdi.packageVariantClosed),
                          selectedIcon: Icon(Mdi.packageVariant),
                          label: Text('Waren'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.calendar_month_outlined),
                          selectedIcon: Icon(Icons.calendar_month),
                          label: Text('Kursplan'),
                        ),
                      ],
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    // Hauptbereich: Entweder Menütext oder normaler Screen
                    Expanded(
                      child: activeMenuItem != null
                          ? _buildMenuItemDisplay(context, activeMenuItem)
                          : navigationShell,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItemDisplay(BuildContext context, String text) {
    return Center(
      child: Text(
        text,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildLeading(BuildContext context, ValueNotifier<bool> isExtended) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: isExtended.value
          ? LayoutBuilder(
              builder: (context, constraints) {
                final showText = constraints.maxWidth >= 200;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showText) ...[const Gap(16), _buildLogo(context)],
                    IconButton(
                      icon: const Icon(Icons.menu_open),
                      tooltip: 'Menü reduzieren',
                      onPressed: () => isExtended.value = false,
                    ),
                  ],
                );
              },
            )
          : IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menü erweitern',
              onPressed: () => isExtended.value = true,
            ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PPO',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        FutureBuilder<String>(
          future: AppVersion.getVersionWithPrefix(),
          builder: (context, snapshot) => Text(
            snapshot.data ?? 'v...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrailing(BuildContext context) {
    return Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Einstellungen',
            onPressed: () => context.push('/master-data'),
          ),
        ),
      ),
    );
  }
}
