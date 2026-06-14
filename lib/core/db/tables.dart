// Drift's check() constraints reference the column inside its own definition
// (the documented idiom), which the analyzer misreads as recursion.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/enums.dart';

/// Public (not private) because Drift inlines this into the generated
/// part file of app_database.dart, which can't see private names from here.
String newUuid() => const Uuid().v4();

/// Conventions shared by every synced table (see FLUTTER_PLAN.md §3):
/// - UUID v4 string primary key (no autoincrement: future sync must merge
///   rows created on different devices without collisions)
/// - createdAt / updatedAt timestamps (UTC)
/// - soft delete: isArchived (user-facing hide) + deletedAt (sync tombstone)
mixin SyncColumns on Table {
  TextColumn get id => text().clientDefault(newUuid)();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// All monetary values are integer minor units (cents). Never floats.
class Accounts extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => textEnum<AccountType>()();
  IntColumn get balanceMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('LKR'))();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

class Categories extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => textEnum<CategoryType>()();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// Whether this category's spending counts toward the overall monthly
  /// budget. On by default; users can exclude categories (e.g. rent, loans)
  /// they don't want weighed against the overall cap.
  BoolColumn get includeInOverallBudget =>
      boolean().withDefault(const Constant(true))();
}

@DataClassName('Person')
class People extends Table with SyncColumns {
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
}

class Transactions extends Table with SyncColumns {
  TextColumn get type => textEnum<TransactionType>()();

  /// Always positive; the sign of the balance effect is derived from [type]
  /// (adjustment uses [amountMinor] with [isNegativeAdjustment]).
  IntColumn get amountMinor => integer().check(amountMinor.isBiggerOrEqualValue(0))();

  /// Adjustments can go both ways; all other types ignore this flag.
  BoolColumn get isNegativeAdjustment =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get date => dateTime()();
  TextColumn get note => text().nullable()();
  @ReferenceName('transactions')
  TextColumn get accountId => text().references(Accounts, #id)();

  /// Destination account — transfers only.
  @ReferenceName('incomingTransfers')
  TextColumn get toAccountId => text().nullable().references(Accounts, #id)();

  /// Expense/income only.
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  /// Lend/borrow/settlement only.
  TextColumn get personId => text().nullable().references(People, #id)();
}

class Budgets extends Table with SyncColumns {
  TextColumn get name => text().nullable()();
  IntColumn get amountMinor => integer().check(amountMinor.isBiggerThanValue(0))();

  /// month + year are null for a *recurring default* budget that applies to
  /// every month, and set for a *month override* that wins for that one month.
  /// A NULL month passes the 1..12 check (CHECK only rejects FALSE), so the
  /// same constraint guards real months without blocking defaults.
  IntColumn get month => integer().nullable().check(month.isBetweenValues(1, 12))();
  IntColumn get year => integer().nullable()();

  /// Overall budget has isOverall = true and categoryId = null.
  /// SQLite UNIQUE treats NULLs as distinct, so uniqueness per
  /// (month, year, category) — including the all-NULL default rows — is
  /// enforced in the repository, not here.
  BoolColumn get isOverall => boolean().withDefault(const Constant(false))();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {month, year, categoryId},
      ];
}

/// Outbound queue for future cloud sync (FLUTTER_PLAN.md §3). Written inside
/// the same DB transaction as every mutation; never read until sync exists.
/// Local-only, so an autoincrement id is fine here.
class ChangeLogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  // 'tableName' is reserved by Drift's Table class.
  TextColumn get entityTable => text().named('table_name')();
  TextColumn get rowId => text()();
  TextColumn get operation => textEnum<ChangeOperation>()();
  DateTimeColumn get changedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
}
