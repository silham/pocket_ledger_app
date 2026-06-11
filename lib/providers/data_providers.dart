import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';
import '../data/accounts_repository.dart';
import '../data/categories_repository.dart';
import '../data/people_repository.dart';
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
