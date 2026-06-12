import 'package:drift/drift.dart';

import '../core/db/app_database.dart';
import '../domain/models/enums.dart';

class AccountsRepository {
  AccountsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Account>> watchActive() => (_db.select(_db.accounts)
        ..where((a) => a.isArchived.equals(false) & a.deletedAt.isNull())
        ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
      .watch();

  Future<Account> create({
    required String name,
    required AccountType type,
    String? color,
    String? icon,
  }) {
    return _db.transaction(() async {
      final account = await _db.into(_db.accounts).insertReturning(
            AccountsCompanion.insert(
              name: name,
              type: type,
              color: Value(color),
              icon: Value(icon),
            ),
          );
      await _db.logChange(
        table: 'accounts',
        rowId: account.id,
        operation: ChangeOperation.insert,
      );
      return account;
    });
  }

  Future<void> update(
    String id, {
    required String name,
    required AccountType type,
    String? color,
  }) {
    return _db.transaction(() async {
      await (_db.update(_db.accounts)..where((a) => a.id.equals(id)))
          .write(AccountsCompanion(
        name: Value(name),
        type: Value(type),
        color: Value(color),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
      await _db.logChange(
        table: 'accounts',
        rowId: id,
        operation: ChangeOperation.update,
      );
    });
  }

  /// Accounts are archived, never deleted: their transactions and balance
  /// history must stay intact.
  Future<void> archive(String id) {
    return _db.transaction(() async {
      await (_db.update(_db.accounts)..where((a) => a.id.equals(id)))
          .write(AccountsCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
      await _db.logChange(
        table: 'accounts',
        rowId: id,
        operation: ChangeOperation.update,
      );
    });
  }
}
