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
  bool get involvesPerson =>
      this == TransactionType.lend ||
      this == TransactionType.borrow ||
      this == TransactionType.settlementReceived ||
      this == TransactionType.settlementPaid;

  bool get isTransfer => this == TransactionType.transfer;

  bool get usesCategory =>
      this == TransactionType.expense || this == TransactionType.income;
}
