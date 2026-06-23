import 'package:drift/drift.dart';

import '../../core/db/app_database.dart';
import '../models/enums.dart';
import 'deltas.dart';

/// Raised when a draft violates the ledger's invariants. The message is
/// developer-facing; the UI maps these to friendly validation text.
class LedgerValidationException implements Exception {
  LedgerValidationException(this.message);
  final String message;

  @override
  String toString() => 'LedgerValidationException: $message';
}

/// Raised when an operation targets a transaction that does not exist
/// (or was already deleted).
class TransactionNotFoundException implements Exception {
  TransactionNotFoundException(this.id);
  final String id;

  @override
  String toString() => 'TransactionNotFoundException: $id';
}

/// Input for creating or editing a transaction. Field requirements depend
/// on [type]; [LedgerService] validates before writing.
class TransactionDraft {
  const TransactionDraft({
    required this.type,
    required this.amountMinor,
    required this.date,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    this.personId,
    this.note,
    this.isNegativeAdjustment = false,
  });

  final TransactionType type;
  final int amountMinor;
  final DateTime date;
  final String accountId;
  final String? toAccountId;
  final String? categoryId;
  final String? personId;
  final String? note;
  final bool isNegativeAdjustment;
}

/// One mismatch found by [LedgerService.verifyAccountBalances].
typedef BalanceMismatch = ({String accountId, int stored, int recomputed});

/// The single write-path for everything that moves money.
///
/// Every mutation runs in one database transaction: the transaction row,
/// the account balance delta(s), and the change_log entries commit or roll
/// back together. Account balances are never written anywhere else.
class LedgerService {
  LedgerService(this._db);

  final AppDatabase _db;

  Future<Transaction> createTransaction(TransactionDraft draft) async {
    _validate(draft);
    return _db.transaction(() => _insertDraft(draft));
  }

  /// Creates several transactions atomically — used by the split-expense flow,
  /// where one paid total fans out into a `lend` per other participant plus an
  /// `expense` for the payer's own share. Every row, its balance deltas, and
  /// its change_log entries commit or roll back together.
  Future<List<Transaction>> createBatch(List<TransactionDraft> drafts) async {
    if (drafts.isEmpty) {
      throw LedgerValidationException('batch needs at least one transaction');
    }
    for (final draft in drafts) {
      _validate(draft);
    }
    return _db.transaction(() async {
      final rows = <Transaction>[];
      for (final draft in drafts) {
        rows.add(await _insertDraft(draft));
      }
      return rows;
    });
  }

  /// Inserts one validated draft and applies its effects. Must run inside an
  /// open `_db.transaction(...)`; callers own the transaction boundary.
  Future<Transaction> _insertDraft(TransactionDraft draft) async {
    final row = await _db.into(_db.transactions).insertReturning(
          TransactionsCompanion.insert(
            type: draft.type,
            amountMinor: draft.amountMinor,
            date: draft.date.toUtc(),
            accountId: draft.accountId,
            toAccountId: Value(draft.toAccountId),
            categoryId: Value(draft.categoryId),
            personId: Value(draft.personId),
            note: Value(draft.note),
            isNegativeAdjustment: Value(draft.isNegativeAdjustment),
          ),
        );
    await _applyDeltas(accountDeltasOf(row));
    await _db.logChange(
      table: 'transactions',
      rowId: row.id,
      operation: ChangeOperation.insert,
    );
    return row;
  }

  /// Edit = reverse the old row's balance effects, apply the new ones,
  /// rewrite the row. Keeps the delta logic single-sourced in deltas.dart.
  Future<Transaction> updateTransaction(
    String id,
    TransactionDraft draft,
  ) async {
    _validate(draft);
    return _db.transaction(() async {
      final old = await _getActive(id);
      await _applyDeltas(_negate(accountDeltasOf(old)));

      final now = DateTime.now().toUtc();
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
          .write(TransactionsCompanion(
        type: Value(draft.type),
        amountMinor: Value(draft.amountMinor),
        date: Value(draft.date.toUtc()),
        accountId: Value(draft.accountId),
        toAccountId: Value(draft.toAccountId),
        categoryId: Value(draft.categoryId),
        personId: Value(draft.personId),
        note: Value(draft.note),
        isNegativeAdjustment: Value(draft.isNegativeAdjustment),
        updatedAt: Value(now),
      ));

      final updated = await _getActive(id);
      await _applyDeltas(accountDeltasOf(updated));
      await _db.logChange(
        table: 'transactions',
        rowId: id,
        operation: ChangeOperation.update,
      );
      return updated;
    });
  }

  /// Soft delete: reverses balance effects and sets the deletedAt tombstone
  /// (kept for future sync). Queries must filter `deletedAt IS NULL`.
  Future<void> deleteTransaction(String id) {
    return _db.transaction(() async {
      final row = await _getActive(id);
      await _applyDeltas(_negate(accountDeltasOf(row)));

      final now = DateTime.now().toUtc();
      await (_db.update(_db.transactions)..where((t) => t.id.equals(id)))
          .write(TransactionsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));
      await _db.logChange(
        table: 'transactions',
        rowId: id,
        operation: ChangeOperation.delete,
      );
    });
  }

  /// Net balance with a person, derived from their transaction history.
  /// Positive = the person owes the user; negative = the user owes them.
  Future<int> personNetBalanceMinor(String personId) async {
    final rows = await (_db.select(_db.transactions)
          ..where((t) => t.personId.equals(personId) & t.deletedAt.isNull()))
        .get();
    return rows.fold<int>(0, (sum, t) => sum + personDeltaOf(t));
  }

  /// Recomputes every account balance from its transaction history and
  /// returns the accounts whose stored balance disagrees. Empty = healthy.
  /// Used by tests and a debug screen; never by production logic.
  Future<List<BalanceMismatch>> verifyAccountBalances() async {
    final accounts = await _db.select(_db.accounts).get();
    final transactions = await (_db.select(_db.transactions)
          ..where((t) => t.deletedAt.isNull()))
        .get();

    final recomputed = <String, int>{for (final a in accounts) a.id: 0};
    for (final t in transactions) {
      for (final entry in accountDeltasOf(t).entries) {
        recomputed.update(entry.key, (v) => v + entry.value);
      }
    }

    return [
      for (final a in accounts)
        if (a.balanceMinor != recomputed[a.id])
          (
            accountId: a.id,
            stored: a.balanceMinor,
            recomputed: recomputed[a.id]!,
          ),
    ];
  }

  // ---------------------------------------------------------------- private

  Future<Transaction> _getActive(String id) async {
    final row = await (_db.select(_db.transactions)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (row == null) throw TransactionNotFoundException(id);
    return row;
  }

  Future<void> _applyDeltas(Map<String, int> deltas) async {
    final now = DateTime.now().toUtc();
    for (final entry in deltas.entries) {
      final updated = await (_db.update(_db.accounts)
            ..where((a) => a.id.equals(entry.key)))
          .write(AccountsCompanion.custom(
        balanceMinor: _db.accounts.balanceMinor + Variable(entry.value),
        updatedAt: Variable(now),
      ));
      if (updated != 1) {
        throw LedgerValidationException('account ${entry.key} not found');
      }
      await _db.logChange(
        table: 'accounts',
        rowId: entry.key,
        operation: ChangeOperation.update,
      );
    }
  }

  Map<String, int> _negate(Map<String, int> deltas) =>
      deltas.map((id, delta) => MapEntry(id, -delta));

  void _validate(TransactionDraft draft) {
    if (draft.amountMinor <= 0) {
      throw LedgerValidationException('amount must be positive');
    }
    if (draft.type.isTransfer) {
      if (draft.toAccountId == null) {
        throw LedgerValidationException('transfer needs a destination account');
      }
      if (draft.toAccountId == draft.accountId) {
        throw LedgerValidationException(
            'transfer source and destination must differ');
      }
    } else if (draft.toAccountId != null) {
      throw LedgerValidationException(
          'only transfers may set a destination account');
    }
    if (draft.type.involvesPerson) {
      if (draft.personId == null) {
        throw LedgerValidationException('${draft.type.name} needs a person');
      }
    } else if (draft.personId != null) {
      throw LedgerValidationException(
          'only lend/borrow/settlement may set a person');
    }
    if (!draft.type.usesCategory && draft.categoryId != null) {
      throw LedgerValidationException(
          'only expense/income may set a category');
    }
  }
}
