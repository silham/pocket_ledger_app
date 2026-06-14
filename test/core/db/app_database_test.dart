import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger_app/core/db/app_database.dart';
import 'package:pocket_ledger_app/core/db/seed_data.dart';
import 'package:pocket_ledger_app/domain/models/enums.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('first launch seeding', () {
    test('seeds 14 expense + 6 income default categories', () async {
      final categories = await db.select(db.categories).get();

      expect(categories, hasLength(20));
      expect(
        categories.where((c) => c.type == CategoryType.expense),
        hasLength(defaultExpenseCategories.length),
      );
      expect(
        categories.where((c) => c.type == CategoryType.income),
        hasLength(defaultIncomeCategories.length),
      );
      expect(categories.every((c) => c.isDefault), isTrue);
      expect(categories.every((c) => c.id.length == 36), isTrue,
          reason: 'ids must be UUIDs');
    });

    test('seeds a default Cash account with zero balance', () async {
      final accounts = await db.select(db.accounts).get();

      expect(accounts, hasLength(1));
      expect(accounts.single.name, 'Cash');
      expect(accounts.single.type, AccountType.cash);
      expect(accounts.single.balanceMinor, 0);
      expect(accounts.single.currency, 'LKR');
    });
  });

  group('sync conventions', () {
    test('rows get UUID ids and UTC timestamps automatically', () async {
      final id = await db.into(db.people).insertReturning(
            PeopleCompanion.insert(name: 'Shazan'),
          );

      expect(id.id.length, 36);
      expect(id.deletedAt, isNull);
      expect(id.createdAt.difference(DateTime.now().toUtc()).inSeconds.abs(),
          lessThan(5));
    });

    test('change log records mutations with the operation type', () async {
      final person = await db.into(db.people).insertReturning(
            PeopleCompanion.insert(name: 'Roshan'),
          );
      await db.logChange(
        table: 'people',
        rowId: person.id,
        operation: ChangeOperation.insert,
      );

      final entries = await db.select(db.changeLogEntries).get();
      expect(entries, hasLength(1));
      expect(entries.single.entityTable, 'people');
      expect(entries.single.rowId, person.id);
      expect(entries.single.operation, ChangeOperation.insert);
    });
  });

  group('schema constraints', () {
    test('foreign keys are enforced', () async {
      expect(
        () => db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                type: TransactionType.expense,
                amountMinor: 100,
                date: DateTime.now().toUtc(),
                accountId: 'nonexistent-account',
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('negative transaction amounts are rejected', () async {
      final account = await db.select(db.accounts).getSingle();
      expect(
        () => db.into(db.transactions).insert(
              TransactionsCompanion.insert(
                type: TransactionType.expense,
                amountMinor: -1,
                date: DateTime.now().toUtc(),
                accountId: account.id,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('unique (month, year, category) budget constraint holds', () async {
      final category =
          (await db.select(db.categories).get()).first;

      Future<int> insertBudget() => db.into(db.budgets).insert(
            BudgetsCompanion.insert(
              amountMinor: 20000_00,
              month: const Value(6),
              year: const Value(2026),
              categoryId: Value(category.id),
            ),
          );

      await insertBudget();
      expect(insertBudget, throwsA(isA<SqliteException>()));
    });
  });
}
