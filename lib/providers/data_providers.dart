import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';
import '../data/accounts_repository.dart';
import '../data/budgets_repository.dart';
import '../data/categories_repository.dart';
import '../data/people_repository.dart';
import '../data/transactions_repository.dart';
import '../domain/ledger/ledger_service.dart';
import '../domain/models/enums.dart';
import 'database_provider.dart';

final ledgerServiceProvider = Provider<LedgerService>(
  (ref) => LedgerService(ref.watch(databaseProvider)),
);

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(ref.watch(databaseProvider)),
);

final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => CategoriesRepository(ref.watch(databaseProvider)),
);

final peopleRepositoryProvider = Provider<PeopleRepository>(
  (ref) => PeopleRepository(ref.watch(databaseProvider)),
);

final budgetsRepositoryProvider = Provider<BudgetsRepository>(
  (ref) => BudgetsRepository(ref.watch(databaseProvider)),
);

/// Live lists for pickers and list screens. Drift streams re-emit on every
/// write, so widgets watching these stay current with no manual refresh.
final activeAccountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(accountsRepositoryProvider).watchActive(),
);

final activeCategoriesProvider =
    StreamProvider.family<List<Category>, CategoryType>(
  (ref, type) => ref.watch(categoriesRepositoryProvider).watchActive(type),
);

final activePeopleProvider = StreamProvider<List<Person>>(
  (ref) => ref.watch(peopleRepositoryProvider).watchActive(),
);

final transactionsRepositoryProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.watch(databaseProvider)),
);

/// Transaction list, newest first. Family key = type filter (null = all).
final transactionListProvider =
    StreamProvider.family<List<TransactionListItem>, TransactionType?>(
  (ref, type) =>
      ref.watch(transactionsRepositoryProvider).watchAll(type: type),
);

/// Named-record key for the month-scoped transaction list.
typedef MonthTransactionFilter = ({TransactionType? type, int year, int month});

/// Transaction list scoped to a calendar month. Family key includes both the
/// month (year + month) and an optional type filter.
final transactionsByMonthProvider =
    StreamProvider.family<List<TransactionListItem>, MonthTransactionFilter>(
  (ref, q) => ref.watch(transactionsRepositoryProvider).watchAll(
        type: q.type,
        year: q.year,
        month: q.month,
      ),
);

/// Every non-deleted transaction row — the dashboard derives its stats
/// from this in one pass.
final allActiveTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.transactions)..where((t) => t.deletedAt.isNull()))
      .watch();
});

/// All categories including archived — archived ones still need their
/// name/color for historical rows (e.g. dashboard breakdown).
final allCategoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.categories)..where((c) => c.deletedAt.isNull())).watch();
});
