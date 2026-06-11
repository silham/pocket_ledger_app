import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger_app/core/db/app_database.dart';
import 'package:pocket_ledger_app/domain/ledger/ledger_service.dart';
import 'package:pocket_ledger_app/domain/models/enums.dart';

void main() {
  late AppDatabase db;
  late LedgerService ledger;
  late String cashId;
  late String bankId;
  late String personId;
  late String foodCategoryId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = LedgerService(db);

    // Seeded Cash account plus a Bank account and a person for tests.
    cashId = (await db.select(db.accounts).getSingle()).id;
    bankId = (await db.into(db.accounts).insertReturning(
          AccountsCompanion.insert(name: 'Bank', type: AccountType.bank),
        ))
        .id;
    personId = (await db.into(db.people).insertReturning(
          PeopleCompanion.insert(name: 'Shazan'),
        ))
        .id;
    foodCategoryId = (await (db.select(db.categories)
              ..where((c) => c.name.equals('Food')))
            .getSingle())
        .id;
  });

  tearDown(() => db.close());

  Future<int> balanceOf(String accountId) async =>
      (await (db.select(db.accounts)..where((a) => a.id.equals(accountId)))
              .getSingle())
          .balanceMinor;

  TransactionDraft draft({
    TransactionType type = TransactionType.expense,
    int amountMinor = 1000,
    String? accountId,
    String? toAccountId,
    String? categoryId,
    String? personId,
    bool isNegativeAdjustment = false,
  }) =>
      TransactionDraft(
        type: type,
        amountMinor: amountMinor,
        date: DateTime.utc(2026, 6, 11),
        accountId: accountId ?? cashId,
        toAccountId: toAccountId,
        categoryId: categoryId,
        personId: personId,
        isNegativeAdjustment: isNegativeAdjustment,
      );

  group('create: balance effects per type', () {
    test('expense decreases the account', () async {
      await ledger.createTransaction(
          draft(type: TransactionType.expense, amountMinor: 450_00, categoryId: foodCategoryId));
      expect(await balanceOf(cashId), -450_00);
    });

    test('income increases the account', () async {
      await ledger.createTransaction(
          draft(type: TransactionType.income, amountMinor: 1000_00));
      expect(await balanceOf(cashId), 1000_00);
    });

    test('transfer moves money between accounts symmetrically', () async {
      await ledger.createTransaction(draft(
        type: TransactionType.transfer,
        amountMinor: 10000_00,
        toAccountId: bankId,
      ));
      expect(await balanceOf(cashId), -10000_00);
      expect(await balanceOf(bankId), 10000_00);
    });

    test('lend decreases account; person owes user', () async {
      await ledger.createTransaction(draft(
        type: TransactionType.lend,
        amountMinor: 2000_00,
        personId: personId,
      ));
      expect(await balanceOf(cashId), -2000_00);
      expect(await ledger.personNetBalanceMinor(personId), 2000_00);
    });

    test('borrow increases account; user owes person', () async {
      await ledger.createTransaction(draft(
        type: TransactionType.borrow,
        amountMinor: 1500_00,
        personId: personId,
      ));
      expect(await balanceOf(cashId), 1500_00);
      expect(await ledger.personNetBalanceMinor(personId), -1500_00);
    });

    test('adjustment can go both ways', () async {
      await ledger.createTransaction(draft(
          type: TransactionType.adjustment, amountMinor: 500_00));
      expect(await balanceOf(cashId), 500_00);

      await ledger.createTransaction(draft(
        type: TransactionType.adjustment,
        amountMinor: 200_00,
        isNegativeAdjustment: true,
      ));
      expect(await balanceOf(cashId), 300_00);
    });
  });

  group('settlements', () {
    test('partial then full settlement of a loan reaches zero', () async {
      await ledger.createTransaction(draft(
          type: TransactionType.lend, amountMinor: 2000_00, personId: personId));

      // Person pays back 500 (partial).
      await ledger.createTransaction(draft(
        type: TransactionType.settlementReceived,
        amountMinor: 500_00,
        personId: personId,
      ));
      expect(await ledger.personNetBalanceMinor(personId), 1500_00);
      expect(await balanceOf(cashId), -1500_00);

      // Person pays the remaining 1500 (full).
      await ledger.createTransaction(draft(
        type: TransactionType.settlementReceived,
        amountMinor: 1500_00,
        personId: personId,
      ));
      expect(await ledger.personNetBalanceMinor(personId), 0);
      expect(await balanceOf(cashId), 0);
    });

    test('user pays back a borrow via settlementPaid', () async {
      await ledger.createTransaction(draft(
          type: TransactionType.borrow, amountMinor: 1000_00, personId: personId));
      await ledger.createTransaction(draft(
        type: TransactionType.settlementPaid,
        amountMinor: 1000_00,
        personId: personId,
      ));
      expect(await ledger.personNetBalanceMinor(personId), 0);
      expect(await balanceOf(cashId), 0);
    });
  });

  group('delete', () {
    test('reverses balance effects and tombstones the row', () async {
      final t = await ledger.createTransaction(
          draft(type: TransactionType.expense, amountMinor: 700_00));
      await ledger.deleteTransaction(t.id);

      expect(await balanceOf(cashId), 0);
      final row = await (db.select(db.transactions)
            ..where((r) => r.id.equals(t.id)))
          .getSingle();
      expect(row.deletedAt, isNotNull);
    });

    test('reverses both sides of a transfer', () async {
      final t = await ledger.createTransaction(draft(
        type: TransactionType.transfer,
        amountMinor: 3000_00,
        toAccountId: bankId,
      ));
      await ledger.deleteTransaction(t.id);
      expect(await balanceOf(cashId), 0);
      expect(await balanceOf(bankId), 0);
    });

    test('deleted settlement no longer affects person balance', () async {
      await ledger.createTransaction(draft(
          type: TransactionType.lend, amountMinor: 1000_00, personId: personId));
      final s = await ledger.createTransaction(draft(
        type: TransactionType.settlementReceived,
        amountMinor: 400_00,
        personId: personId,
      ));
      await ledger.deleteTransaction(s.id);
      expect(await ledger.personNetBalanceMinor(personId), 1000_00);
    });

    test('deleting twice throws TransactionNotFound', () async {
      final t = await ledger.createTransaction(draft(amountMinor: 100));
      await ledger.deleteTransaction(t.id);
      expect(
        () => ledger.deleteTransaction(t.id),
        throwsA(isA<TransactionNotFoundException>()),
      );
    });
  });

  group('update', () {
    test('changing the amount re-applies the delta', () async {
      final t = await ledger.createTransaction(
          draft(type: TransactionType.expense, amountMinor: 1000_00));
      await ledger.updateTransaction(
          t.id, draft(type: TransactionType.expense, amountMinor: 250_00));
      expect(await balanceOf(cashId), -250_00);
    });

    test('moving an expense to another account fixes both balances', () async {
      final t = await ledger.createTransaction(
          draft(type: TransactionType.expense, amountMinor: 1000_00));
      await ledger.updateTransaction(t.id,
          draft(type: TransactionType.expense, amountMinor: 1000_00, accountId: bankId));
      expect(await balanceOf(cashId), 0);
      expect(await balanceOf(bankId), -1000_00);
    });

    test('changing type expense -> income flips the effect', () async {
      final t = await ledger.createTransaction(
          draft(type: TransactionType.expense, amountMinor: 800_00));
      await ledger.updateTransaction(
          t.id, draft(type: TransactionType.income, amountMinor: 800_00));
      expect(await balanceOf(cashId), 800_00);
    });
  });

  group('validation', () {
    test('rejects zero and negative amounts', () {
      expect(() => ledger.createTransaction(draft(amountMinor: 0)),
          throwsA(isA<LedgerValidationException>()));
      expect(() => ledger.createTransaction(draft(amountMinor: -5)),
          throwsA(isA<LedgerValidationException>()));
    });

    test('rejects transfer to the same account', () {
      expect(
        () => ledger.createTransaction(draft(
            type: TransactionType.transfer, toAccountId: cashId)),
        throwsA(isA<LedgerValidationException>()),
      );
    });

    test('rejects transfer without destination', () {
      expect(
        () => ledger.createTransaction(draft(type: TransactionType.transfer)),
        throwsA(isA<LedgerValidationException>()),
      );
    });

    test('rejects lend without person', () {
      expect(
        () => ledger.createTransaction(draft(type: TransactionType.lend)),
        throwsA(isA<LedgerValidationException>()),
      );
    });

    test('rejects person on a plain expense', () {
      expect(
        () => ledger.createTransaction(
            draft(type: TransactionType.expense, personId: personId)),
        throwsA(isA<LedgerValidationException>()),
      );
    });

    test('rejects category on a transfer', () {
      expect(
        () => ledger.createTransaction(draft(
          type: TransactionType.transfer,
          toAccountId: bankId,
          categoryId: foodCategoryId,
        )),
        throwsA(isA<LedgerValidationException>()),
      );
    });

    test('failed validation leaves balances untouched', () async {
      try {
        await ledger.createTransaction(draft(type: TransactionType.lend));
      } on LedgerValidationException {
        // expected
      }
      expect(await balanceOf(cashId), 0);
      expect(await ledger.verifyAccountBalances(), isEmpty);
    });
  });

  group('integrity', () {
    test('random operation sequences keep stored balances consistent',
        () async {
      final rng = Random(42); // fixed seed: deterministic test
      final created = <String>[];

      for (var i = 0; i < 200; i++) {
        final op = rng.nextInt(10);
        try {
          if (op < 7 || created.isEmpty) {
            final type = TransactionType
                .values[rng.nextInt(TransactionType.values.length)];
            final t = await ledger.createTransaction(TransactionDraft(
              type: type,
              amountMinor: rng.nextInt(100000) + 1,
              date: DateTime.utc(2026, rng.nextInt(12) + 1, rng.nextInt(28) + 1),
              accountId: rng.nextBool() ? cashId : bankId,
              toAccountId: type == TransactionType.transfer
                  ? (rng.nextBool() ? cashId : bankId)
                  : null,
              personId: type.involvesPerson ? personId : null,
              isNegativeAdjustment: rng.nextBool(),
            ));
            created.add(t.id);
          } else if (op < 9) {
            final t = created.removeAt(rng.nextInt(created.length));
            await ledger.deleteTransaction(t);
          } else {
            final id = created[rng.nextInt(created.length)];
            await ledger.updateTransaction(
              id,
              TransactionDraft(
                type: TransactionType.expense,
                amountMinor: rng.nextInt(50000) + 1,
                date: DateTime.utc(2026, 1, 1),
                accountId: rng.nextBool() ? cashId : bankId,
              ),
            );
          }
        } on LedgerValidationException {
          // invalid random combos (e.g. transfer to same account) are fine
        }
      }

      expect(await ledger.verifyAccountBalances(), isEmpty,
          reason: 'stored balances must equal recomputed balances');
    });
  });
}
