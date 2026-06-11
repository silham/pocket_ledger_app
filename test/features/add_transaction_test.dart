import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger_app/app.dart';
import 'package:pocket_ledger_app/core/db/app_database.dart';
import 'package:pocket_ledger_app/domain/models/enums.dart';
import 'package:pocket_ledger_app/providers/database_provider.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const PocketLedgerApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The Save button sits at the bottom of the form's ListView and can be
  // below the test viewport.
  Future<void> tapSave(WidgetTester tester) async {
    await tester.dragUntilVisible(
      find.text('Save'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('records an expense end-to-end', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '450.50');
    await tapSave(tester);

    // Returned to the dashboard with a confirmation.
    expect(find.text('Expense saved'), findsOneWidget);

    final transactions = await db.select(db.transactions).get();
    expect(transactions, hasLength(1));
    expect(transactions.single.type, TransactionType.expense);
    expect(transactions.single.amountMinor, 450_50);

    final cash = await db.select(db.accounts).getSingle();
    expect(cash.balanceMinor, -450_50);
  });

  testWidgets('lend requires a person before saving', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lend'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '100');
    await tapSave(tester);

    expect(find.text('Pick a person'), findsOneWidget);
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  testWidgets('rejects an invalid amount inline', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '0');
    await tapSave(tester);

    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  testWidgets('transfer form exposes destination account picker',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    expect(find.text('From account'), findsOneWidget);
    expect(find.text('To account'), findsOneWidget);
    expect(find.text('Category'), findsNothing);
  });
}
