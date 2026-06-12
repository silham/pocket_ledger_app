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
  late String shazanId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = LedgerService(db);
    cashId = (await db.select(db.accounts).getSingle()).id;
    shazanId = (await db.into(db.people).insertReturning(
          PeopleCompanion.insert(name: 'Shazan'),
        ))
        .id;
  });

  tearDown(() => db.close());

  Future<void> pumpOnPeopleTab(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const PocketLedgerApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('People'));
    await tester.pumpAndSettle();
  }

  Future<void> lend(int amountMinor) => ledger.createTransaction(
        TransactionDraft(
          type: TransactionType.lend,
          amountMinor: amountMinor,
          date: DateTime.now(),
          accountId: cashId,
          personId: shazanId,
        ),
      );

  testWidgets('people list shows derived net balance', (tester) async {
    await lend(2000_00);
    await ledger.createTransaction(TransactionDraft(
      type: TransactionType.settlementReceived,
      amountMinor: 500_00,
      date: DateTime.now(),
      accountId: cashId,
      personId: shazanId,
    ));

    await pumpOnPeopleTab(tester);

    expect(find.text('Shazan'), findsOneWidget);
    expect(find.text('owes you'), findsOneWidget);
    expect(find.text('Rs. 1,500.00'), findsOneWidget);
  });

  testWidgets('ledger settle flow prefills and clears the debt',
      (tester) async {
    await lend(1500_00);
    await pumpOnPeopleTab(tester);

    await tester.tap(find.text('Shazan'));
    await tester.pumpAndSettle();

    // Ledger header and prefilled settle action.
    expect(find.text('Shazan owes you'), findsOneWidget);
    await tester.tap(find.text('Record repayment'));
    await tester.pumpAndSettle();

    // Form landed preconfigured: type, person and outstanding amount.
    expect(find.text('Add Transaction'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byType(TextField).first)
          .controller
          ?.text,
      '1500',
    );
    expect(find.text('Shazan'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Save'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Back on the ledger: settled, balance restored.
    expect(find.text('All settled'), findsAtLeastNWidgets(1));
    final cash = await db.select(db.accounts).getSingle();
    expect(cash.balanceMinor, 0);
  });

  testWidgets('add person via the people tab', (tester) async {
    await pumpOnPeopleTab(tester);

    await tester.tap(find.byIcon(Icons.person_add_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Roshan');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Roshan'), findsOneWidget);
    expect(find.text('settled'), findsWidgets);
  });

  testWidgets('archiving hides the person from the list', (tester) async {
    await lend(100_00);
    await pumpOnPeopleTab(tester);

    await tester.tap(find.text('Shazan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    // Back on the people list, Shazan is gone but the row still exists.
    expect(find.text('No people yet'), findsOneWidget);
    final person = await db.select(db.people).getSingle();
    expect(person.isArchived, isTrue);
  });
}
