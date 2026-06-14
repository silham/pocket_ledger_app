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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await seedDefaults(this);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Categories gain an opt-out flag for the overall budget (on by
            // default, so existing categories keep counting).
            await m.addColumn(
                categories, categories.includeInOverallBudget);
            // Budgets.month / .year become nullable so one row can act as a
            // recurring default. TableMigration rebuilds the table to loosen
            // the NOT NULL constraints, copying existing rows across.
            await m.alterTable(TableMigration(budgets));
          }
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
