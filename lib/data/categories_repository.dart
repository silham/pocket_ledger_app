import 'package:drift/drift.dart';

import '../core/db/app_database.dart';
import '../domain/models/enums.dart';

class CategoriesRepository {
  CategoriesRepository(this._db);

  final AppDatabase _db;

  Stream<List<Category>> watchActive(CategoryType type) =>
      (_db.select(_db.categories)
            ..where((c) =>
                c.type.equalsValue(type) &
                c.isArchived.equals(false) &
                c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .watch();
}
