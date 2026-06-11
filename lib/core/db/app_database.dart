import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/models/enums.dart';
import 'seed_data.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Accounts, Categories, People, Transactions, Budgets, ChangeLogEntries],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// In-memory database for tests.
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDefaults(this);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Records a mutation in the change_log (future sync outbound queue).
  /// Must be called inside the same `transaction(...)` as the mutation itself.
  Future<void> logChange({
    required String table,
    required String rowId,
    required ChangeOperation operation,
  }) {
    return into(changeLogEntries).insert(
      ChangeLogEntriesCompanion.insert(
        entityTable: table,
        rowId: rowId,
        operation: operation,
      ),
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'pocket_ledger');
  }
}
