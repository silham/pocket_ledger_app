import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger_app/core/db/app_database.dart';
import 'package:pocket_ledger_app/data/transactions_repository.dart';
import 'package:pocket_ledger_app/domain/models/enums.dart';
import 'package:pocket_ledger_app/features/people/people_providers.dart';

void main() {
  final base = DateTime(2026, 1, 1);
  var counter = 0;

  // Builds a newest-first list from oldest-first args, mirroring how the
  // repository hands history to splitDebtHistory.
  List<TransactionListItem> history(List<(TransactionType, int)> oldestFirst) {
    final items = [
      for (final (type, amount) in oldestFirst)
        TransactionListItem(
          transaction: Transaction(
            id: 't${counter++}',
            type: type,
            amountMinor: amount,
            isNegativeAdjustment: false,
            date: base.add(Duration(days: counter)),
            accountId: 'cash',
            personId: 'p1',
            createdAt: base,
            updatedAt: base,
          ),
          accountName: 'Cash',
        ),
    ];
    return items.reversed.toList(); // newest first
  }

  test('fully repaid debt collapses entirely into settled', () {
    final split = splitDebtHistory(history([
      (TransactionType.lend, 100_00),
      (TransactionType.settlementReceived, 100_00),
    ]));

    expect(split.unsettled, isEmpty);
    expect(split.settled, hasLength(2));
  });

  test('only the run after the last zero point stays unsettled', () {
    final split = splitDebtHistory(history([
      (TransactionType.lend, 100_00), // settled...
      (TransactionType.settlementReceived, 100_00), // ...back to zero here
      (TransactionType.lend, 50_00), // new open balance
    ]));

    expect(split.unsettled, hasLength(1));
    expect(split.unsettled.single.transaction.amountMinor, 50_00);
    expect(split.settled, hasLength(2));
  });

  test('a debt that never returns to zero has no settled history', () {
    final split = splitDebtHistory(history([
      (TransactionType.lend, 100_00),
      (TransactionType.lend, 50_00),
    ]));

    expect(split.settled, isEmpty);
    expect(split.unsettled, hasLength(2));
    // Newest first.
    expect(split.unsettled.first.transaction.amountMinor, 50_00);
  });

  test('partial repayment keeps the whole run open', () {
    final split = splitDebtHistory(history([
      (TransactionType.lend, 100_00),
      (TransactionType.settlementReceived, 40_00), // still owed 60
    ]));

    expect(split.settled, isEmpty);
    expect(split.unsettled, hasLength(2));
  });
}
