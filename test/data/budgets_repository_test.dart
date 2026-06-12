import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger_app/core/db/app_database.dart';
import 'package:pocket_ledger_app/data/budgets_repository.dart';

void main() {
  late AppDatabase db;
  late BudgetsRepository repo;
  late String foodId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BudgetsRepository(db);
    foodId = (await (db.select(db.categories)
              ..where((c) => c.name.equals('Food')))
            .getSingle())
        .id;
  });

  tearDown(() => db.close());

  Future<List<Budget>> activeBudgets() => (db.select(db.budgets)
        ..where((b) => b.deletedAt.isNull()))
      .get();

  test('setBudget creates, then updates instead of duplicating', () async {
    await repo.setBudget(
        year: 2026, month: 6, amountMinor: 20000_00, categoryId: foodId);
    await repo.setBudget(
        year: 2026, month: 6, amountMinor: 25000_00, categoryId: foodId);

    final budgets = await activeBudgets();
    expect(budgets, hasLength(1));
    expect(budgets.single.amountMinor, 25000_00);
    expect(budgets.single.isOverall, isFalse);
  });

  test('overall budget (null category) is tracked separately', () async {
    await repo.setBudget(year: 2026, month: 6, amountMinor: 50000_00);
    await repo.setBudget(
        year: 2026, month: 6, amountMinor: 20000_00, categoryId: foodId);
    await repo.setBudget(year: 2026, month: 6, amountMinor: 60000_00);

    final budgets = await activeBudgets();
    expect(budgets, hasLength(2));
    final overall = budgets.singleWhere((b) => b.isOverall);
    expect(overall.amountMinor, 60000_00);
    expect(overall.categoryId, isNull);
  });

  test('same category in different months are separate budgets', () async {
    await repo.setBudget(
        year: 2026, month: 6, amountMinor: 100_00, categoryId: foodId);
    await repo.setBudget(
        year: 2026, month: 7, amountMinor: 200_00, categoryId: foodId);

    expect(await activeBudgets(), hasLength(2));
  });

  test('delete tombstones; re-creating resurrects the same row', () async {
    await repo.setBudget(
        year: 2026, month: 6, amountMinor: 100_00, categoryId: foodId);
    final original = (await activeBudgets()).single;

    await repo.delete(original.id);
    expect(await activeBudgets(), isEmpty);

    // Unique (year, month, category) index still holds the tombstone —
    // this must not throw, and must reuse the row.
    await repo.setBudget(
        year: 2026, month: 6, amountMinor: 300_00, categoryId: foodId);
    final resurrected = (await activeBudgets()).single;
    expect(resurrected.id, original.id);
    expect(resurrected.amountMinor, 300_00);
    expect(resurrected.deletedAt, isNull);
  });
}
