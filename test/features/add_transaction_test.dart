import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger_app/app.dart';
import 'package:pocket_ledger_app/core/db/app_database.dart';
import 'package:pocket_ledger_app/data/people_repository.dart';
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

  // Fields near the bottom of the form's ListView can sit below the test
  // viewport; scroll them into reach before tapping.
  Future<void> scrollTo(WidgetTester tester, Finder target) {
    return tester.dragUntilVisible(
      target,
      find.byType(ListView),
      const Offset(0, -100),
    );
  }

  Future<void> tapSave(WidgetTester tester) async {
    await scrollTo(tester, find.text('Save'));
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

  testWidgets('someone paying for me records a borrow plus the expense',
      (tester) async {
    final person = await PeopleRepository(db).create('Amal');
    await pumpApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '500');
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Someone paid for me'));
    await tester.tap(find.text('Someone paid for me'));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('Paid by'));
    await tester.tap(find.text('Paid by'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Amal'));
    await tester.pumpAndSettle();

    await tapSave(tester);

    expect(find.text('Saved — you owe Amal Rs. 500.00'), findsOneWidget);

    final transactions = await db.select(db.transactions).get();
    expect(transactions, hasLength(2));

    final borrow = transactions
        .firstWhere((t) => t.type == TransactionType.borrow);
    expect(borrow.amountMinor, 500_00);
    expect(borrow.personId, person.id);

    final expense = transactions
        .firstWhere((t) => t.type == TransactionType.expense);
    expect(expense.amountMinor, 500_00);
    expect(expense.personId, isNull);

    // The money never passed through the account, so the two rows cancel.
    final cash = await db.select(db.accounts).getSingle();
    expect(cash.balanceMinor, 0);
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
