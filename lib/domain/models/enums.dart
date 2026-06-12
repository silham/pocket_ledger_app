/// Core domain enums, mirroring the reference PWA's Prisma enums.
/// Stored in SQLite as their `name` strings (stable — do not rename members;
/// renaming would corrupt existing rows and break future sync).
library;

enum AccountType { cash, bank, wallet, savings, creditCard, other }

enum TransactionType {
  expense,
  income,
  transfer,
  lend,
  borrow,
  settlementReceived,
  settlementPaid,
  adjustment,
}

enum CategoryType { expense, income }

/// Operation recorded in the change_log table (future sync outbound queue).
enum ChangeOperation { insert, update, delete }

extension TransactionTypeX on TransactionType {
  /// User-facing label, used by the add form, filters, and list rows.
  String get label => switch (this) {
        TransactionType.expense => 'Expense',
        TransactionType.income => 'Income',
        TransactionType.transfer => 'Transfer',
        TransactionType.lend => 'Lend',
        TransactionType.borrow => 'Borrow',
        TransactionType.settlementReceived => 'Settle In',
        TransactionType.settlementPaid => 'Settle Out',
        TransactionType.adjustment => 'Adjust',
      };

  /// Sign of the effect on the *main* account, for display purposes.
  /// (+1, -1; transfers are 0 = neutral.)
  int get displaySign => switch (this) {
        TransactionType.income ||
        TransactionType.borrow ||
        TransactionType.settlementReceived =>
          1,
        TransactionType.expense ||
        TransactionType.lend ||
        TransactionType.settlementPaid =>
          -1,
        TransactionType.transfer || TransactionType.adjustment => 0,
      };

  bool get involvesPerson =>
      this == TransactionType.lend ||
      this == TransactionType.borrow ||
      this == TransactionType.settlementReceived ||
      this == TransactionType.settlementPaid;

  bool get isTransfer => this == TransactionType.transfer;

  bool get usesCategory =>
      this == TransactionType.expense || this == TransactionType.income;
}
