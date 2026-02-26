import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mdi/mdi.dart';
import 'main_menu_bar.dart';

/// The main structural wrapper (shell) for the application UI.
///
/// This widget provides the persistent navigation layout including the
/// top [MainMenuBar] and the side [NavigationRail]. It acts as the 
/// container for different feature screens which are provided via the
/// [child] property and updated by the declarative router logic (`go_router`).
class AppShell extends StatelessWidget {
  /// The current feature screen widget to display inside the shell.
  final Widget child;

  /// Creates a new AppShell.
  const AppShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/members')) return 1;
    if (location.startsWith('/contracts')) return 2;
    if (location.startsWith('/pos')) return 3;
    if (location.startsWith('/calendar')) return 4;
    // Map /master-data to calendar tab as well
    if (location.startsWith('/master-data')) return 4;
    return 0; // dashboard
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/members');
        break;
      case 2:
        context.go('/contracts');
        break;
      case 3:
        context.go('/pos');
        break;
      case 4:
        context.go('/calendar');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      body: Column(
        children: [
          // Obere Mac/Windows Menüleiste (Platform-unabhängig gebaut)
          const MainMenuBar(),
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) => _onItemTapped(index, context),
                  labelType: isDesktop ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                  extended: isDesktop, // Erweitert auf großen Bildschirmen
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
                      label: Text('Verträge'),
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
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
