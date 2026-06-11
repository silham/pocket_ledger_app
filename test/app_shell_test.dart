import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger_app/app.dart';

void main() {
  testWidgets('app boots with bottom navigation and opens Add screen',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PocketLedgerApp()));
    await tester.pumpAndSettle();

    expect(find.text('Pocket Ledger'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);

    // Tabs switch screens.
    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();
    expect(find.text('Lending & borrowing ledger (Phase 7)'), findsOneWidget);

    // Center FAB opens the add-transaction flow.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Add Transaction'), findsOneWidget);
  });
}
