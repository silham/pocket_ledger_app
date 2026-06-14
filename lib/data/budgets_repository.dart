import 'package:drift/drift.dart';

import '../core/db/app_database.dart';
import '../domain/models/enums.dart';

class BudgetsRepository {
  BudgetsRepository(this._db);

  final AppDatabase _db;

  /// Recurring default budgets (null month + year): the overall default and
  /// any per-category defaults that apply to every month.
  Stream<List<Budget>> watchDefaults() =>
      (_db.select(_db.budgets)
            ..where((b) =>
                b.year.isNull() &
                b.month.isNull() &
                b.deletedAt.isNull()))
          .watch();

  /// Month-specific override budgets for the given month.
  Stream<List<Budget>> watchMonth(int year, int month) =>
      (_db.select(_db.budgets)
            ..where((b) =>
                b.year.equals(year) &
                b.month.equals(month) &
                b.deletedAt.isNull()))
          .watch();

  /// Create-or-update for (year, month, category). A null year + month makes a
  /// recurring default; categoryId == null makes it the overall budget. SQLite's
  /// unique index can't enforce single-NULL rows, so the upsert here is the guard.
  Future<void> setBudget({
    int? year,
    int? month,
    required int amountMinor,
    String? categoryId,
  }) {
    return _db.transaction(() async {
      // Includes soft-deleted rows: the unique (year, month, category) index
      // still sees them, so a re-created budget must resurrect the tombstone.
      final existingQuery = _db.select(_db.budgets)
        ..where((b) => year == null ? b.year.isNull() : b.year.equals(year))
        ..where((b) => month == null ? b.month.isNull() : b.month.equals(month))
        ..where((b) => categoryId == null
            ? b.categoryId.isNull()
            : b.categoryId.equals(categoryId));
      final existing = await existingQuery.getSingleOrNull();

      if (existing != null) {
        await (_db.update(_db.budgets)
              ..where((b) => b.id.equals(existing.id)))
            .write(BudgetsCompanion(
          amountMinor: Value(amountMinor),
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now().toUtc()),
        ));
        await _db.logChange(
          table: 'budgets',
          rowId: existing.id,
          operation: ChangeOperation.update,
        );
      } else {
        final budget = await _db.into(_db.budgets).insertReturning(
              BudgetsCompanion.insert(
                amountMinor: amountMinor,
                month: Value(month),
                year: Value(year),
                isOverall: Value(categoryId == null),
                categoryId: Value(categoryId),
              ),
            );
        await _db.logChange(
          table: 'budgets',
          rowId: budget.id,
          operation: ChangeOperation.insert,
        );
      }
    });
  }

  /// Soft delete (deletedAt tombstone for future sync).
  Future<void> delete(String id) {
    return _db.transaction(() async {
      final now = DateTime.now().toUtc();
      await (_db.update(_db.budgets)..where((b) => b.id.equals(id)))
          .write(BudgetsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));
      await _db.logChange(
        table: 'budgets',
        rowId: id,
        operation: ChangeOperation.delete,
      );
    });
  }
}
