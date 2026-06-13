import 'package:drift/drift.dart';

import '../core/db/app_database.dart';
import '../domain/models/enums.dart';

class CategoriesRepository {
  CategoriesRepository(this._db);

  final AppDatabase _db;

  Stream<List<Category>> watchActive(CategoryType type) =>
      _activeQuery(type).watch();

  /// One-shot snapshot, for pickers that just need the current list at tap
  /// time (avoids relying on a stream provider's first emission).
  Future<List<Category>> getActive(CategoryType type) =>
      _activeQuery(type).get();

  SimpleSelectStatement<$CategoriesTable, Category> _activeQuery(
          CategoryType type) =>
      _db.select(_db.categories)
        ..where((c) =>
            c.type.equalsValue(type) &
            c.isArchived.equals(false) &
            c.deletedAt.isNull())
        ..orderBy([(c) => OrderingTerm.asc(c.name)]);

  Future<Category> create({
    required String name,
    required CategoryType type,
    String? icon,
    String? color,
  }) {
    return _db.transaction(() async {
      final category = await _db.into(_db.categories).insertReturning(
            CategoriesCompanion.insert(
              name: name,
              type: type,
              icon: Value(icon),
              color: Value(color),
            ),
          );
      await _db.logChange(
        table: 'categories',
        rowId: category.id,
        operation: ChangeOperation.insert,
      );
      return category;
    });
  }

  Future<void> update(
    String id, {
    required String name,
    String? icon,
    String? color,
  }) {
    return _db.transaction(() async {
      await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
          .write(CategoriesCompanion(
        name: Value(name),
        icon: Value(icon),
        color: Value(color),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
      await _db.logChange(
        table: 'categories',
        rowId: id,
        operation: ChangeOperation.update,
      );
    });
  }

  /// Archive, never delete: historical transactions keep their category.
  Future<void> archive(String id) {
    return _db.transaction(() async {
      await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
          .write(CategoriesCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
      await _db.logChange(
        table: 'categories',
        rowId: id,
        operation: ChangeOperation.update,
      );
    });
  }
}
