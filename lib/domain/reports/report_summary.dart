import '../../core/db/app_database.dart';
import '../dashboard/dashboard_summary.dart' show CategorySpend;
import '../ledger/deltas.dart';
import '../models/enums.dart';

/// Figures for the Reports screen, for one calendar month. Pure.
class ReportSummary {
  const ReportSummary({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.categorySpending,
    required this.owedToMeMinor,
    required this.iOweMinor,
  });

  final int incomeMinor;
  final int expenseMinor;

  /// Expense per category in the month, largest first.
  final List<CategorySpend> categorySpending;

  /// Current (not month-scoped) debt position.
  final int owedToMeMinor;
  final int iOweMinor;

  int get netMinor => incomeMinor - expenseMinor;

  factory ReportSummary.compute({
    required List<Transaction> transactions,
    required int year,
    required int month,
  }) {
    var income = 0;
    var expense = 0;
    final byCategory = <String?, int>{};
    final personNets = <String, int>{};

    for (final t in transactions) {
      final local = t.date.toLocal();
      final inMonth = local.year == year && local.month == month;

      if (inMonth && t.type == TransactionType.income) {
        income += t.amountMinor;
      } else if (inMonth && t.type == TransactionType.expense) {
        expense += t.amountMinor;
        byCategory.update(t.categoryId, (v) => v + t.amountMinor,
            ifAbsent: () => t.amountMinor);
      }

      final pDelta = personDeltaOf(t);
      if (pDelta != 0 && t.personId != null) {
        personNets.update(t.personId!, (v) => v + pDelta,
            ifAbsent: () => pDelta);
      }
    }

    var owedToMe = 0;
    var iOwe = 0;
    for (final net in personNets.values) {
      if (net > 0) owedToMe += net;
      if (net < 0) iOwe -= net;
    }

    final spending = [
      for (final entry in byCategory.entries)
        CategorySpend(categoryId: entry.key, amountMinor: entry.value),
    ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));

    return ReportSummary(
      incomeMinor: income,
      expenseMinor: expense,
      categorySpending: spending,
      owedToMeMinor: owedToMe,
      iOweMinor: iOwe,
    );
  }
}
