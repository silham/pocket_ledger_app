import 'package:drift/drift.dart';

import '../core/db/app_database.dart';
import '../domain/models/enums.dart';

class PeopleRepository {
  PeopleRepository(this._db);

  final AppDatabase _db;

  Stream<List<Person>> watchActive() => _activeQuery().watch();

  /// One-shot snapshot, for pickers that just need the current list at tap
  /// time (avoids relying on a stream provider's first emission).
  Future<List<Person>> getActive() => _activeQuery().get();

  SimpleSelectStatement<$PeopleTable, Person> _activeQuery() =>
      _db.select(_db.people)
        ..where((p) => p.isArchived.equals(false) & p.deletedAt.isNull())
        ..orderBy([(p) => OrderingTerm.asc(p.name)]);

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

  Future<void> update(
    String id, {
    required String name,
    String? phone,
    String? email,
    String? notes,
  }) {
    return _db.transaction(() async {
      await (_db.update(_db.people)..where((p) => p.id.equals(id)))
          .write(PeopleCompanion(
        name: Value(name),
        phone: Value(phone),
        email: Value(email),
        notes: Value(notes),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
      await _db.logChange(
        table: 'people',
        rowId: id,
        operation: ChangeOperation.update,
      );
    });
  }

  /// People with history are archived, never hard-deleted (PWA rule).
  Future<void> archive(String id) {
    return _db.transaction(() async {
      await (_db.update(_db.people)..where((p) => p.id.equals(id)))
          .write(PeopleCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
      await _db.logChange(
        table: 'people',
        rowId: id,
        operation: ChangeOperation.update,
      );
    });
  }

  Stream<Person?> watchById(String id) =>
      (_db.select(_db.people)..where((p) => p.id.equals(id)))
          .watchSingleOrNull();
}
