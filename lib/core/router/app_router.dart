import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../features/dashboard/dashboard_screen.dart';
import '../../features/members/members_screen.dart';
import '../../features/contracts/contracts_screen.dart';
import '../../features/pos/pos_screen.dart';
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
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/members',
            builder: (context, state) => const MembersScreen(),
          ),
          GoRoute(
            path: '/contracts',
            builder: (context, state) => const ContractsScreen(),
          ),
          GoRoute(
            path: '/pos',
            builder: (context, state) => const PosScreen(),
          ),
        ],
      ),
    ],
  );
});
