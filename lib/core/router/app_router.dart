
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/dashboard/dashboard_screen.dart';
import '../../features/members/members_screen.dart';
import '../../features/beitraege/beitraege_screen.dart';
import '../../features/leistungen/leistungen_screen.dart';
import '../../features/waren/waren_screen.dart';
import '../../features/pos/pos_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/stammdaten/presentation/screens/stammdaten_screen.dart';
import '../../common_widgets/app_shell.dart';

/// The global routing configuration for the ClupData application.
///
/// This provider exposes a [GoRouter] instance that handles the navigation
/// logic of the app. It uses an [AppShell] widget inside a [ShellRoute] 
/// to maintain a persistent navigation layout (e.g., side menu) while 
/// switching between the feature screens: Dashboard, Members, Contracts, and POS.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/members',
                builder: (context, state) => const MembersScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/leistungen',
                builder: (context, state) => const LeistungenScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/beitraege',
                builder: (context, state) => const BeitraegeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/waren',
                builder: (context, state) => const WarenScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pos',
                builder: (context, state) => const PosScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
              GoRoute(
                path: '/master-data',
                builder: (context, state) => const StammdatenScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
