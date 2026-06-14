import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widget/home_widget_service.dart';
import 'domain/dashboard/dashboard_summary.dart';
import 'features/dashboard/dashboard_providers.dart';
import 'providers/settings_providers.dart';

/// App-wide messenger so flows can show snackbars after popping their
/// own scaffold (e.g. "saved" toast after the add-transaction screen closes).
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showAppSnackBar(String message) {
  appMessengerKey.currentState
    ?..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class PocketLedgerApp extends ConsumerStatefulWidget {
  const PocketLedgerApp({super.key});

  @override
  ConsumerState<PocketLedgerApp> createState() => _PocketLedgerAppState();
}

class _PocketLedgerAppState extends ConsumerState<PocketLedgerApp> {
  // Owned by this state so rebuilds don't recreate the router
  // (which would reset navigation).
  late final GoRouter _router = createAppRouter();

  @override
  void initState() {
    super.initState();
    _initHomeWidget();
  }

  /// Listen for taps on the home-screen widget. A tap arrives either as the
  /// URI the app was cold-launched with, or live on the widgetClicked stream.
  Future<void> _initHomeWidget() async {
    HomeWidget.widgetClicked.listen(_handleWidgetUri);
    _handleWidgetUri(await HomeWidget.initiallyLaunchedFromHomeWidget());
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    // pocketledger://add  ->  open the quick-add transaction flow.
    if (uri.host == HomeWidgetService.addTransactionUri.host) {
      // Defer until the router has a navigator (cold-start taps fire early).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _router.push(AppRoutes.add);
      });
    }
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the home-screen widget's "spent today" figure in sync. Fires on the
    // first computed summary (loading -> value) and every later DB write.
    ref.listen<DashboardSummary?>(dashboardSummaryProvider, (_, summary) {
      if (summary != null) {
        HomeWidgetService.updateDailySpending(
          todayExpenseMinor: summary.todayExpenseMinor,
          now: DateTime.now(),
        );
      }
    });

    return MaterialApp.router(
      title: 'Pocket Ledger',
      scaffoldMessengerKey: appMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,
    );
  }
}
