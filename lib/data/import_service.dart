import 'dart:convert';

import '../core/db/app_database.dart';
import 'export_service.dart';

/// Thrown when a backup file is missing, malformed, or from an app version
/// this build can't read. Its [message] is safe to show to the user.
class ImportException implements Exception {
  ImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// How many rows of each kind a restore wrote.
class ImportResult {
  const ImportResult({
    required this.accounts,
    required this.categories,
    required this.people,
    required this.transactions,
    required this.budgets,
  });

  final int accounts;
  final int categories;
  final int people;
  final int transactions;
  final int budgets;

  int get total => accounts + categories + people + transactions + budgets;
}

/// Restores a JSON backup produced by [ExportService].
///
/// This is a *full replace*, not a merge: every table is wiped and the backup's
/// rows are re-inserted verbatim, IDs and all. That's deliberate — account
/// balances are stored as a snapshot alongside the transactions that produced
/// them, so replaying transactions through the ledger would double-count.
/// Copying the rows exactly keeps the snapshot internally consistent.
class ImportService {
  ImportService(this._db);

  final AppDatabase _db;

  Future<ImportResult> restoreJson(String jsonString) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (_) {
      throw ImportException('That file is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ImportException('That file is not a Pocket Ledger backup.');
    }
    final Map<String, dynamic> root = decoded;

    if (root['app'] != 'pocket_ledger') {
      throw ImportException('That file is not a Pocket Ledger backup.');
    }
    final version = root['formatVersion'];
    if (version is! int || version > ExportService.formatVersion) {
      throw ImportException(
          'This backup was made by a newer version of the app. '
          'Update Pocket Ledger and try again.');
    }

    List<Map<String, dynamic>> rowsOf(String key) {
      final value = root[key];
      if (value == null) return const [];
      if (value is! List) {
        throw ImportException('The "$key" section of the backup is corrupt.');
      }
      return [
        for (final e in value)
          if (e is Map<String, dynamic>)
            e
          else
            throw ImportException('The "$key" section of the backup is corrupt.')
      ];
    }

    final accountRows = rowsOf('accounts');
    final categoryRows = rowsOf('categories');
    final peopleRows = rowsOf('people');
    final transactionRows = rowsOf('transactions');
    final budgetRows = rowsOf('budgets');

    // Backups from before schema v2 predate this flag; default it to on so the
    // category keeps counting toward the overall budget, matching the migration.
    for (final r in categoryRows) {
      r.putIfAbsent('includeInOverallBudget', () => true);
    }

    // Parse everything up front: a single bad row aborts before we touch the DB,
    // so a malformed backup can never leave the user with a half-wiped database.
    final List<Account> accounts;
    final List<Category> categories;
    final List<Person> people;
    final List<Transaction> transactions;
    final List<Budget> budgets;
    try {
      accounts = [for (final r in accountRows) Account.fromJson(r)];
      categories = [for (final r in categoryRows) Category.fromJson(r)];
      people = [for (final r in peopleRows) Person.fromJson(r)];
      transactions = [for (final r in transactionRows) Transaction.fromJson(r)];
      budgets = [for (final r in budgetRows) Budget.fromJson(r)];
    } catch (e) {
      throw ImportException('The backup contains a record this app '
          "can't read. It may be corrupt.");
    }

    await _db.transaction(() async {
      // Delete children before parents so foreign keys stay satisfied. The
      // change log is the outbound sync queue; its entries point at rows we're
      // about to replace, so clear it too.
      await _db.delete(_db.changeLogEntries).go();
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.people).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.accounts).go();

      // Insert parents before children. toCompanion(true) carries every column,
      // including id/createdAt, so the restore is byte-for-byte faithful.
      await _db.batch((b) {
        b.insertAll(_db.accounts,
            [for (final r in accounts) r.toCompanion(true)]);
        b.insertAll(_db.categories,
            [for (final r in categories) r.toCompanion(true)]);
        b.insertAll(_db.people, [for (final r in people) r.toCompanion(true)]);
        b.insertAll(_db.transactions,
            [for (final r in transactions) r.toCompanion(true)]);
        b.insertAll(_db.budgets,
            [for (final r in budgets) r.toCompanion(true)]);
      });
    });

    return ImportResult(
      accounts: accounts.length,
      categories: categories.length,
      people: people.length,
      transactions: transactions.length,
      budgets: budgets.length,
    );
  }
}
