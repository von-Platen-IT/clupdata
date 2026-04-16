import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mdi/mdi.dart';
import 'package:gap/gap.dart';
import '../core/providers/active_menu_item_provider.dart';
import '../core/utils/app_version.dart';
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

    return Scaffold(
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
                      icon: Icon(Mdi.packageVariantClosed),
                      selectedIcon: Icon(Mdi.packageVariant),
                      label: Text('Waren'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long),
                      label: Text('Rechnungen'),
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
