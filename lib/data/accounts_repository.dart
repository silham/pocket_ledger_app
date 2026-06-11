import 'package:drift/drift.dart';

import '../core/db/app_database.dart';

class AccountsRepository {
  AccountsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Account>> watchActive() => (_db.select(_db.accounts)
        ..where((a) => a.isArchived.equals(false) & a.deletedAt.isNull())
        ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
      .watch();
}
