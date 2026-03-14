import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:mdi/mdi.dart';
import 'package:gap/gap.dart';
import '../core/utils/app_version.dart';
import 'main_menu_bar.dart';

/// The main structural wrapper (shell) for the application UI.
///
/// This widget provides the persistent navigation layout including the
/// top [MainMenuBar] and the side [NavigationRail]. It acts as the
/// container for different feature screens which are provided via the
/// [navigationShell] property and updated by the declarative router logic (`go_router`).
class AppShell extends HookWidget {
  /// The navigation shell providing the current stateful route branches.
  final StatefulNavigationShell navigationShell;

  /// Creates a new AppShell.
  const AppShell({super.key, required this.navigationShell});

  void _onItemTapped(int index) {
    // Using goBranch as recommended for StatefulShellRoute
    navigationShell.goBranch(
      index,
      // A common pattern when using bottom navigation bars is to support
      // navigating to the initial location when tapping the item that is
      // already active.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    // State hook to toggle the expanded state of the sidebar locally
    final isExtended = useState(isDesktop);

    // Dynamische Versionsnummer aus pubspec.yaml laden
    final versionAsync = useFuture(AppVersion.getVersionWithPrefix());

    // Keep the state in sync with screen size changes mostly, but allow overrides
    useEffect(() {
      isExtended.value = isDesktop;
      return null;
    }, [isDesktop]);

    return Scaffold(
      body: Column(
        children: [
          // Obere Mac/Windows Menüleiste (Platform-unabhängig gebaut)
          const MainMenuBar(),
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _onItemTapped,
                  labelType: isExtended.value
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  extended: isExtended.value,
                  leading: Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isExtended.value)
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // PPO Text nur anzeigen, wenn mindestens 200px verfügbar sind
                              final showText = constraints.maxWidth >= 200;
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showText) ...[
                                    const Gap(16),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'PPO',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                        ),
                                        Text(
                                          versionAsync.data ?? 'v...',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  IconButton(
                                    icon: const Icon(Icons.menu_open),
                                    tooltip: 'Menü reduzieren',
                                    onPressed: () => isExtended.value = false,
                                  ),
                                ],
                              );
                            },
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.menu),
                            tooltip: 'Menü erweitern',
                            onPressed: () => isExtended.value = true,
                          ),
                      ],
                    ),
                  ),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.settings_outlined),
                              tooltip: 'Einstellungen',
                              onPressed: () {
                                context.push('/master-data');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
                Expanded(child: navigationShell),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
