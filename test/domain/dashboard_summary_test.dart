import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger_app/core/db/app_database.dart';
import 'package:pocket_ledger_app/domain/dashboard/dashboard_summary.dart';
import 'package:pocket_ledger_app/domain/models/enums.dart';

void main() {
  final now = DateTime(2026, 6, 11, 14, 30); // fixed local "now"

  Account account(String id, int balanceMinor) => Account(
        id: id,
        name: id,
        type: AccountType.cash,
        balanceMinor: balanceMinor,
        currency: 'LKR',
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );

  var txCounter = 0;
  Transaction tx(
    TransactionType type,
    int amountMinor, {
    DateTime? date,
    String account = 'cash',
    String? toAccount,
    String? category,
    String? person,
    bool negativeAdjustment = false,
  }) =>
      Transaction(
        id: 't${txCounter++}',
        type: type,
        amountMinor: amountMinor,
        isNegativeAdjustment: negativeAdjustment,
        date: date ?? now,
        accountId: account,
        toAccountId: toAccount,
        categoryId: category,
        personId: person,
        createdAt: now,
        updatedAt: now,
      );

  test('totals, today and past-30-day figures', () {
    // now = 11 Jun -> the 30-day window starts 13 May.
    final summary = DashboardSummary.compute(
      accounts: [account('cash', 5000_00), account('bank', 1000_00)],
      transactions: [
        tx(TransactionType.expense, 450_00), // today
        tx(TransactionType.expense, 100_00,
            date: DateTime(2026, 5, 20)), // in window, not today
        tx(TransactionType.expense, 999_00,
            date: DateTime(2026, 5, 1)), // outside the window
        tx(TransactionType.income, 2000_00, date: DateTime(2026, 6, 5)),
      ],
      now: now,
    );

    expect(summary.totalBalanceMinor, 6000_00);
    expect(summary.todayExpenseMinor, 450_00);
    expect(summary.last30ExpenseMinor, 550_00);
    expect(summary.last30IncomeMinor, 2000_00);
    expect(summary.last30NetMinor, 1450_00);
  });

  test('debt summary nets per person before splitting owed/owing', () {
    final summary = DashboardSummary.compute(
      accounts: [account('cash', 0)],
      transactions: [
        // Shazan: lent 2000, repaid 500 -> owes 1500
        tx(TransactionType.lend, 2000_00, person: 'shazan'),
        tx(TransactionType.settlementReceived, 500_00, person: 'shazan'),
        // Roshan: borrowed 1000 -> user owes 1000
        tx(TransactionType.borrow, 1000_00, person: 'roshan'),
      ],
      now: now,
    );

    expect(summary.owedToMeMinor, 1500_00);
    expect(summary.iOweMinor, 1000_00);
  });

  test('daily balance series walks back from the current total', () {
    final summary = DashboardSummary.compute(
      accounts: [account('cash', 1000_00)],
      transactions: [
        // Today: spent 200 (so yesterday's close was 1200).
        tx(TransactionType.expense, 200_00),
        // 5 days ago: income 500 (close 4 days ago was 1200; before, 700).
        tx(TransactionType.income, 500_00,
            date: now.subtract(const Duration(days: 5))),
      ],
      now: now,
    );

    final days = summary.dailyBalances;
    expect(days, hasLength(30));
    expect(days.last.balanceMinor, 1000_00, reason: 'today = stored total');
    expect(days[28].balanceMinor, 1200_00, reason: 'yesterday close');
    expect(days[24].balanceMinor, 1200_00, reason: 'income day close');
    expect(days[23].balanceMinor, 700_00, reason: 'before the income');
    expect(days.first.balanceMinor, 700_00);
  });

  test('transfers do not move the total balance series', () {
    final summary = DashboardSummary.compute(
      accounts: [account('cash', 500_00), account('bank', 500_00)],
      transactions: [
        tx(TransactionType.transfer, 300_00,
            account: 'cash', toAccount: 'bank'),
      ],
      now: now,
    );

    expect(
      summary.dailyBalances.map((d) => d.balanceMinor).toSet(),
      {1000_00},
      reason: 'a transfer is balance-neutral',
    );
  });

  test('category spending covers last 30 days only, sorted desc', () {
    final summary = DashboardSummary.compute(
      accounts: [account('cash', 0)],
      transactions: [
        tx(TransactionType.expense, 100_00, category: 'food'),
        tx(TransactionType.expense, 300_00, category: 'travel'),
        tx(TransactionType.expense, 50_00, category: 'food'),
        tx(TransactionType.expense, 999_00,
            category: 'food',
            date: now.subtract(const Duration(days: 40))), // outside window
        tx(TransactionType.expense, 25_00), // uncategorised
      ],
      now: now,
    );

    expect(summary.categorySpending, hasLength(3));
    expect(summary.categorySpending[0].categoryId, 'travel');
    expect(summary.categorySpending[0].amountMinor, 300_00);
    expect(summary.categorySpending[1].categoryId, 'food');
    expect(summary.categorySpending[1].amountMinor, 150_00);
    expect(summary.categorySpending[2].categoryId, isNull);
  });

  test('daily expenses bucket spending per day over the last 30 days', () {
    final summary = DashboardSummary.compute(
      accounts: [account('cash', 0)],
      transactions: [
        tx(TransactionType.expense, 200_00), // today
        tx(TransactionType.expense, 50_00), // today again -> same bucket
        tx(TransactionType.expense, 100_00,
            date: now.subtract(const Duration(days: 5))),
        tx(TransactionType.expense, 999_00,
            date: now.subtract(const Duration(days: 40))), // outside window
        tx(TransactionType.income, 500_00), // not an expense
      ],
      now: now,
    );

    final days = summary.dailyExpenses;
    expect(days, hasLength(30));
    expect(days.last.amountMinor, 250_00, reason: 'today = 200 + 50');
    expect(days[24].amountMinor, 100_00, reason: '5 days ago');
    expect(days.first.amountMinor, 0, reason: 'no spend that day');
    expect(days.fold<int>(0, (s, d) => s + d.amountMinor), 350_00,
        reason: 'the 999 is outside the window');
  });
}
