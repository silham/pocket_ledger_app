import 'dart:convert';

import '../core/db/app_database.dart';

/// Serialises the whole database to a JSON document — the user's backup
/// until cloud sync exists. Soft-deleted rows are included on purpose:
/// a backup should be a faithful copy, and tombstones matter for sync.
class ExportService {
  ExportService(this._db);

  final AppDatabase _db;

  static const formatVersion = 1;

  Future<String> buildJson({DateTime? now}) async {
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();
    final people = await _db.select(_db.people).get();
    final transactions = await _db.select(_db.transactions).get();
    final budgets = await _db.select(_db.budgets).get();

    return const JsonEncoder.withIndent('  ').convert({
      'app': 'pocket_ledger',
      'formatVersion': formatVersion,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'accounts': [for (final r in accounts) r.toJson()],
      'categories': [for (final r in categories) r.toJson()],
      'people': [for (final r in people) r.toJson()],
      'transactions': [for (final r in transactions) r.toJson()],
      'budgets': [for (final r in budgets) r.toJson()],
    });
  }
}
