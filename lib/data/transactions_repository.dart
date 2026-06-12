import 'package:drift/drift.dart';

import '../core/db/app_database.dart';
import '../domain/models/enums.dart';

/// A transaction row joined with the names the list UI needs.
class TransactionListItem {
  const TransactionListItem({
    required this.transaction,
    required this.accountName,
    this.toAccountName,
    this.categoryName,
    this.categoryColor,
    this.personName,
  });

  final Transaction transaction;
  final String accountName;
  final String? toAccountName;
  final String? categoryName;
  final String? categoryColor;
  final String? personName;
}

class TransactionsRepository {
  TransactionsRepository(this._db);

  final AppDatabase _db;

  /// Newest first, soft-deleted rows excluded, optionally filtered by
  /// type, person, and/or a calendar month (year + month).
  Stream<List<TransactionListItem>> watchAll({
    TransactionType? type,
    String? personId,
    int? year,
    int? month,
  }) {
    final toAccounts = _db.alias(_db.accounts, 'to_accounts');

    final query = _db.select(_db.transactions).join([
      innerJoin(
        _db.accounts,
        _db.accounts.id.equalsExp(_db.transactions.accountId),
      ),
      leftOuterJoin(
        toAccounts,
        toAccounts.id.equalsExp(_db.transactions.toAccountId),
      ),
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
      leftOuterJoin(
        _db.people,
        _db.people.id.equalsExp(_db.transactions.personId),
      ),
    ])
      ..where(_db.transactions.deletedAt.isNull())
      ..orderBy([
        OrderingTerm.desc(_db.transactions.date),
        OrderingTerm.desc(_db.transactions.createdAt),
      ]);

    if (type != null) {
      query.where(_db.transactions.type.equalsValue(type));
    }
    if (personId != null) {
      query.where(_db.transactions.personId.equals(personId));
    }
    if (year != null && month != null) {
      final start = DateTime(year, month);
      final end = DateTime(year, month + 1); // Dart normalises overflow months
      query.where(
        _db.transactions.date.isBiggerOrEqualValue(start) &
            _db.transactions.date.isSmallerThanValue(end),
      );
    }

    return query.watch().map((rows) => [
          for (final row in rows)
            TransactionListItem(
              transaction: row.readTable(_db.transactions),
              accountName: row.readTable(_db.accounts).name,
              toAccountName: row.readTableOrNull(toAccounts)?.name,
              categoryName: row.readTableOrNull(_db.categories)?.name,
              categoryColor: row.readTableOrNull(_db.categories)?.color,
              personName: row.readTableOrNull(_db.people)?.name,
            ),
        ]);
  }

  Future<Transaction?> findById(String id) =>
      (_db.select(_db.transactions)
            ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
          .getSingleOrNull();
}
