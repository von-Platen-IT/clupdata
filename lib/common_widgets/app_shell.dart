import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:mdi/mdi.dart';
import 'package:gap/gap.dart';
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
                  labelType: isExtended.value ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                  extended: isExtended.value, 
                  leading: Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: Column(
                      children: [
                        if (isExtended.value)
                          Row(
                            children: [
                              const Gap(16),
                              const Text(
                                'ClupData',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.deepOrange,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const Gap(24),
                              IconButton(
                                icon: const Icon(Icons.menu_open),
                                tooltip: 'Menü reduzieren',
                                onPressed: () => isExtended.value = false,
                              ),
                              const Gap(8),
                            ],
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.menu),
                            tooltip: 'Menü erweitern',
                            onPressed: () => isExtended.value = true,
                          ),
                        const Gap(16),
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
                                // TODO: Add settings navigation or dialog
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Mdi.viewDashboardOutline),
                      selectedIcon: Icon(Mdi.viewDashboard),
                      label: Text('Dashboard'),
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
                      icon: Icon(Mdi.packageVariantClosed),
                      selectedIcon: Icon(Mdi.packageVariant),
                      label: Text('Waren'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Mdi.cashRegister),
                      selectedIcon: Icon(Mdi.cashRegister),
                      label: Text('Kasse'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: Text('Kursplan'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: navigationShell,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
