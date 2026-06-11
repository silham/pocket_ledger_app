/// Pure balance-effect functions for every transaction type.
/// Reference: FLUTTER_PLAN.md §4 and the PWA's server-side handlers
/// (pocket-ledger-web-PWA: /api/transactions).
///
/// All values are integer minor units. `amountMinor` is always positive in
/// the database; signs are derived here and nowhere else.
library;

import '../../core/db/app_database.dart';
import '../models/enums.dart';

/// Per-account balance changes caused by a transaction.
/// Key: account id, value: signed delta in minor units.
Map<String, int> accountDeltas({
  required TransactionType type,
  required int amountMinor,
  required String accountId,
  String? toAccountId,
  bool isNegativeAdjustment = false,
}) {
  switch (type) {
    case TransactionType.expense:
    case TransactionType.lend:
    case TransactionType.settlementPaid:
      return {accountId: -amountMinor};
    case TransactionType.income:
    case TransactionType.borrow:
    case TransactionType.settlementReceived:
      return {accountId: amountMinor};
    case TransactionType.transfer:
      return {accountId: -amountMinor, toAccountId!: amountMinor};
    case TransactionType.adjustment:
      return {accountId: isNegativeAdjustment ? -amountMinor : amountMinor};
  }
}

/// Effect of a transaction on a person's net balance.
/// Positive net balance = the person owes the user;
/// negative = the user owes the person (same convention as the PWA).
int personDelta({required TransactionType type, required int amountMinor}) {
  switch (type) {
    case TransactionType.lend:
    case TransactionType.settlementPaid:
      return amountMinor;
    case TransactionType.borrow:
    case TransactionType.settlementReceived:
      return -amountMinor;
    default:
      return 0;
  }
}

/// Deltas for a stored row (convenience over [accountDeltas]).
Map<String, int> accountDeltasOf(Transaction t) => accountDeltas(
      type: t.type,
      amountMinor: t.amountMinor,
      accountId: t.accountId,
      toAccountId: t.toAccountId,
      isNegativeAdjustment: t.isNegativeAdjustment,
    );

int personDeltaOf(Transaction t) =>
    personDelta(type: t.type, amountMinor: t.amountMinor);
