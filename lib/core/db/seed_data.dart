import 'package:drift/drift.dart';

import '../../domain/models/enums.dart';
import 'app_database.dart';

/// Default categories and starter account, seeded on first launch.
/// Mirrors the reference PWA's registration seeding
/// (pocket-ledger-web-PWA: /api/auth/register).
///
/// `icon` values are stable keys mapped to Material icons in the UI layer —
/// they are stored in the DB, so never rename them.
const defaultExpenseCategories = [
  (name: 'Food', icon: 'food', color: '#f97316'),
  (name: 'Transport', icon: 'transport', color: '#3b82f6'),
  (name: 'Education', icon: 'education', color: '#8b5cf6'),
  (name: 'Subscriptions', icon: 'subscriptions', color: '#ec4899'),
  (name: 'Shopping', icon: 'shopping', color: '#f59e0b'),
  (name: 'Health', icon: 'health', color: '#ef4444'),
  (name: 'Entertainment', icon: 'entertainment', color: '#06b6d4'),
  (name: 'Family', icon: 'family', color: '#10b981'),
  (name: 'Bills', icon: 'bills', color: '#64748b'),
  (name: 'Mobile/Data', icon: 'mobile', color: '#0ea5e9'),
  (name: 'Travel', icon: 'travel', color: '#14b8a6'),
  (name: 'University', icon: 'university', color: '#a855f7'),
  (name: 'Business', icon: 'business', color: '#84cc16'),
  (name: 'Other', icon: 'other', color: '#9ca3af'),
];

const defaultIncomeCategories = [
  (name: 'Salary', icon: 'salary', color: '#22c55e'),
  (name: 'Freelance', icon: 'freelance', color: '#3b82f6'),
  (name: 'Business', icon: 'business', color: '#84cc16'),
  (name: 'Gift', icon: 'gift', color: '#ec4899'),
  (name: 'Refund', icon: 'refund', color: '#f59e0b'),
  (name: 'Other', icon: 'other', color: '#9ca3af'),
];

Future<void> seedDefaults(AppDatabase db) async {
  await db.batch((batch) {
    batch.insertAll(db.categories, [
      for (final c in defaultExpenseCategories)
        CategoriesCompanion.insert(
          name: c.name,
          type: CategoryType.expense,
          icon: Value(c.icon),
          color: Value(c.color),
          isDefault: const Value(true),
        ),
      for (final c in defaultIncomeCategories)
        CategoriesCompanion.insert(
          name: c.name,
          type: CategoryType.income,
          icon: Value(c.icon),
          color: Value(c.color),
          isDefault: const Value(true),
        ),
    ]);
    batch.insert(
      db.accounts,
      AccountsCompanion.insert(
        name: 'Cash',
        type: AccountType.cash,
        icon: const Value('cash'),
        color: const Value('#22c55e'),
      ),
    );
  });
}
