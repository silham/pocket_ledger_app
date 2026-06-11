import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/add_transaction/add_transaction_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/people/people_screen.dart';
import '../../features/transactions/transactions_screen.dart';
import '../widgets/app_shell.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const transactions = '/transactions';
  static const add = '/add';
  static const people = '/people';
  static const more = '/more';
}

/// Factory rather than a global: each app instance gets its own router
/// (a shared singleton would leak navigation state across widget tests).
GoRouter createAppRouter() => GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const DashboardScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: AppRoutes.transactions,
            builder: (context, state) => const TransactionsScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: AppRoutes.people,
            builder: (context, state) => const PeopleScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: AppRoutes.more,
            builder: (context, state) => const MoreScreen(),
          ),
        ]),
      ],
    ),
    // Add transaction opens on top of the shell as a full-screen flow,
    // so entry is fast and the bottom bar doesn't distract from it.
    GoRoute(
      path: AppRoutes.add,
      pageBuilder: (context, state) => const MaterialPage(
        fullscreenDialog: true,
        child: AddTransactionScreen(),
      ),
    ),
      ],
    );
