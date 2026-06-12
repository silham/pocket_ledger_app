import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger_app/app.dart';
import 'package:pocket_ledger_app/core/db/app_database.dart';
import 'package:pocket_ledger_app/domain/ledger/ledger_service.dart';
import 'package:pocket_ledger_app/domain/models/enums.dart';
import 'package:pocket_ledger_app/providers/database_provider.dart';

void main() {
  late AppDatabase db;
  late LedgerService ledger;
  late String cashId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = LedgerService(db);
    cashId = (await db.select(db.accounts).getSingle()).id;
  });

  tearDown(() => db.close());

  Future<void> pumpOnHistoryTab(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const PocketLedgerApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
  }

  Future<void> addExpense(int amountMinor, {DateTime? date}) =>
      ledger.createTransaction(TransactionDraft(
        type: TransactionType.expense,
        amountMinor: amountMinor,
        date: date ?? DateTime.now(),
        accountId: cashId,
      ));

  testWidgets('groups transactions under day headers', (tester) async {
    await addExpense(450_00);
    await addExpense(100_00,
        date: DateTime.now().subtract(const Duration(days: 1)));

    await pumpOnHistoryTab(tester);

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('-Rs. 450.00'), findsOneWidget);
    expect(find.text('-Rs. 100.00'), findsOneWidget);
  });

  testWidgets('type filter narrows the list', (tester) async {
    await addExpense(450_00);
    await ledger.createTransaction(TransactionDraft(
      type: TransactionType.income,
      amountMinor: 900_00,
      date: DateTime.now(),
      accountId: cashId,
    ));

    await pumpOnHistoryTab(tester);
    expect(find.text('-Rs. 450.00'), findsOneWidget);
    expect(find.text('+Rs. 900.00'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Income'));
    await tester.pumpAndSettle();

    expect(find.text('-Rs. 450.00'), findsNothing);
    expect(find.text('+Rs. 900.00'), findsOneWidget);
  });

  testWidgets('swipe to delete restores the balance', (tester) async {
    await addExpense(700_00);
    await pumpOnHistoryTab(tester);

    await tester.drag(find.byType(Dismissible), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No transactions yet'), findsOneWidget);
    final cash = await db.select(db.accounts).getSingle();
    expect(cash.balanceMinor, 0);
  });

  testWidgets('tapping a row opens edit and update fixes the balance',
      (tester) async {
    await addExpense(1000_00);
    await pumpOnHistoryTab(tester);

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Transaction'), findsOneWidget);
    final amountField = find.byType(TextField).first;
    expect(
      tester.widget<TextField>(amountField).controller?.text,
      '1000',
    );

    await tester.enterText(amountField, '250');
    await tester.dragUntilVisible(
      find.text('Update'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(find.text('Expense updated'), findsOneWidget);
    final cash = await db.select(db.accounts).getSingle();
    expect(cash.balanceMinor, -250_00);
  });
}
