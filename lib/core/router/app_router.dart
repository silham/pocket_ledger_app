import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/add_transaction/add_transaction_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/more/accounts/accounts_screen.dart';
import '../../features/more/budgets/budgets_screen.dart';
import '../../features/more/categories/categories_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/more/reports/reports_screen.dart';
import '../../features/more/settings/settings_screen.dart';
import '../../features/people/people_screen.dart';
import '../../features/people/person_ledger_screen.dart';
import '../../domain/models/enums.dart';
import '../../features/transactions/transactions_screen.dart';
import '../widgets/app_shell.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const transactions = '/transactions';
  static const add = '/add';
  static const people = '/people';
  static const more = '/more';
  static const moreAccounts = '/more/accounts';
  static const moreCategories = '/more/categories';
  static const moreBudgets = '/more/budgets';
  static const moreReports = '/more/reports';
  static const moreSettings = '/more/settings';

  static String personLedger(String id) => '/people/$id';
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
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => PersonLedgerScreen(
                  personId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: AppRoutes.more,
            builder: (context, state) => const MoreScreen(),
            routes: [
              GoRoute(
                path: 'accounts',
                builder: (context, state) => const AccountsScreen(),
              ),
              GoRoute(
                path: 'categories',
                builder: (context, state) => const CategoriesScreen(),
              ),
              GoRoute(
                path: 'budgets',
                builder: (context, state) => const BudgetsScreen(),
              ),
              GoRoute(
                path: 'reports',
                builder: (context, state) => const ReportsScreen(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ]),
      ],
    ),
    // Add transaction opens on top of the shell as a full-screen flow,
    // so entry is fast and the bottom bar doesn't distract from it.
    GoRoute(
      path: AppRoutes.add,
      pageBuilder: (context, state) {
        // '/add?edit=<id>' opens the form prefilled for editing.
        // '/add?type=<name>&person=<id>&account=<id>&amount=<minor>'
        // preselects values (used by the person-ledger settle flow and the
        // accounts-screen "adjust balance" action).
        final params = state.uri.queryParameters;
        return MaterialPage(
          fullscreenDialog: true,
          child: AddTransactionScreen(
            editId: params['edit'],
            initialType: TransactionType.values.asNameMap()[params['type']],
            initialPersonId: params['person'],
            initialAccountId: params['account'],
            initialAmountMinor: int.tryParse(params['amount'] ?? ''),
          ),
        );
      },
    ),
      ],
    );
