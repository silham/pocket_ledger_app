import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger_app/core/db/app_database.dart';
import 'package:pocket_ledger_app/domain/models/enums.dart';
import 'package:pocket_ledger_app/domain/reports/report_summary.dart';

void main() {
  final base = DateTime(2026, 6, 15);
  var counter = 0;

  Transaction tx(
    TransactionType type,
    int amountMinor, {
    DateTime? date,
    String? category,
    String? person,
  }) =>
      Transaction(
        id: 't${counter++}',
        type: type,
        amountMinor: amountMinor,
        isNegativeAdjustment: false,
        date: date ?? base,
        accountId: 'cash',
        categoryId: category,
        personId: person,
        createdAt: base,
        updatedAt: base,
      );

  test('scopes income/expense/categories to the requested month', () {
    final report = ReportSummary.compute(
      transactions: [
        tx(TransactionType.income, 5000_00),
        tx(TransactionType.expense, 1200_00, category: 'food'),
        tx(TransactionType.expense, 300_00, category: 'food',
            date: DateTime(2026, 5, 30)), // previous month
        tx(TransactionType.expense, 800_00, category: 'travel'),
      ],
      year: 2026,
      month: 6,
    );

    expect(report.incomeMinor, 5000_00);
    expect(report.expenseMinor, 2000_00);
    expect(report.netMinor, 3000_00);
    expect(report.categorySpending, hasLength(2));
    expect(report.categorySpending.first.categoryId, 'food');
  });

  test('debt position uses all history, not just the month', () {
    final report = ReportSummary.compute(
      transactions: [
        tx(TransactionType.lend, 1000_00, person: 'a',
            date: DateTime(2026, 1, 1)),
        tx(TransactionType.borrow, 400_00, person: 'b',
            date: DateTime(2026, 2, 1)),
      ],
      year: 2026,
      month: 6,
    );

    expect(report.owedToMeMinor, 1000_00);
    expect(report.iOweMinor, 400_00);
  });
}
