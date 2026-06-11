import 'package:drift/drift.dart';

import '../core/db/app_database.dart';
import '../domain/models/enums.dart';

class PeopleRepository {
  PeopleRepository(this._db);

  final AppDatabase _db;

  Stream<List<Person>> watchActive() => (_db.select(_db.people)
        ..where((p) => p.isArchived.equals(false) & p.deletedAt.isNull())
        ..orderBy([(p) => OrderingTerm.asc(p.name)]))
      .watch();

  Future<Person> create(String name, {String? phone, String? email}) {
    return _db.transaction(() async {
      final person = await _db.into(_db.people).insertReturning(
            PeopleCompanion.insert(
              name: name,
              phone: Value(phone),
              email: Value(email),
            ),
          );
      await _db.logChange(
        table: 'people',
        rowId: person.id,
        operation: ChangeOperation.insert,
      );
      return person;
    });
  }
}
