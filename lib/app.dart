import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// App-wide messenger so flows can show snackbars after popping their
/// own scaffold (e.g. "saved" toast after the add-transaction screen closes).
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showAppSnackBar(String message) {
  appMessengerKey.currentState
    ?..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class PocketLedgerApp extends StatefulWidget {
  const PocketLedgerApp({super.key});

  @override
  State<PocketLedgerApp> createState() => _PocketLedgerAppState();
}

class _PocketLedgerAppState extends State<PocketLedgerApp> {
  // Owned by this state so rebuilds don't recreate the router
  // (which would reset navigation).
  late final GoRouter _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pocket Ledger',
      scaffoldMessengerKey: appMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
