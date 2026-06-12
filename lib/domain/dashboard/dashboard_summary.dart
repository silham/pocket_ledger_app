import '../../core/db/app_database.dart';
import '../ledger/deltas.dart';
import '../models/enums.dart';

/// One slice of the spending-by-category breakdown.
class CategorySpend {
  const CategorySpend({
    required this.categoryId,
    required this.amountMinor,
  });

  final String? categoryId; // null = uncategorised
  final int amountMinor;
}

/// End-of-day total balance, for the 30-day line chart.
class DailyBalance {
  const DailyBalance({required this.day, required this.balanceMinor});

  final DateTime day; // local calendar day (midnight)
  final int balanceMinor;
}

/// Everything the dashboard shows, computed in one pass over the
/// active accounts and non-deleted transactions. Pure: no I/O, no clock —
/// callers pass `now` (which also makes tests deterministic).
class DashboardSummary {
  const DashboardSummary({
    required this.totalBalanceMinor,
    required this.todayExpenseMinor,
    required this.monthIncomeMinor,
    required this.monthExpenseMinor,
    required this.owedToMeMinor,
    required this.iOweMinor,
    required this.dailyBalances,
    required this.categorySpending,
  });

  final int totalBalanceMinor;
  final int todayExpenseMinor;
  final int monthIncomeMinor;
  final int monthExpenseMinor;

  /// Sum of positive person balances (people who owe the user).
  final int owedToMeMinor;

  /// Sum of negative person balances, as a positive number (what the user owes).
  final int iOweMinor;

  /// Last 30 days, oldest first.
  final List<DailyBalance> dailyBalances;

  /// Expense totals per category over the last 30 days, largest first.
  final List<CategorySpend> categorySpending;

  int get monthNetMinor => monthIncomeMinor - monthExpenseMinor;

  factory DashboardSummary.compute({
    required List<Account> accounts,
    required List<Transaction> transactions,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final chartStart = today.subtract(const Duration(days: 29));

    // Archived accounts still hold money conceptually, but the PWA counts
    // only active accounts in the total; we do the same (list is pre-filtered).
    final totalBalance =
        accounts.fold<int>(0, (sum, a) => sum + a.balanceMinor);

    var todayExpense = 0;
    var monthIncome = 0;
    var monthExpense = 0;
    final personNets = <String, int>{};
    final dayDeltas = <DateTime, int>{}; // calendar day -> total-balance delta
    final categoryTotals = <String?, int>{};

    for (final t in transactions) {
      final local = t.date.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final isToday = day == today;
      final isThisMonth = local.year == now.year && local.month == now.month;
      final inChartWindow = !day.isBefore(chartStart) && !day.isAfter(today);

      if (t.type == TransactionType.expense) {
        if (isToday) todayExpense += t.amountMinor;
        if (isThisMonth) monthExpense += t.amountMinor;
        if (inChartWindow) {
          categoryTotals.update(
            t.categoryId,
            (v) => v + t.amountMinor,
            ifAbsent: () => t.amountMinor,
          );
        }
      } else if (t.type == TransactionType.income && isThisMonth) {
        monthIncome += t.amountMinor;
      }

      final pDelta = personDeltaOf(t);
      if (pDelta != 0 && t.personId != null) {
        personNets.update(t.personId!, (v) => v + pDelta,
            ifAbsent: () => pDelta);
      }

      // Net effect on the total balance that day (transfers cancel out).
      final totalDelta =
          accountDeltasOf(t).values.fold<int>(0, (s, d) => s + d);
      if (totalDelta != 0) {
        dayDeltas.update(day, (v) => v + totalDelta,
            ifAbsent: () => totalDelta);
      }
    }

    var owedToMe = 0;
    var iOwe = 0;
    for (final net in personNets.values) {
      if (net > 0) owedToMe += net;
      if (net < 0) iOwe -= net;
    }

    // Walk backwards from today's known total to reconstruct each
    // end-of-day balance.
    final balances = List<DailyBalance>.filled(
      30,
      DailyBalance(day: today, balanceMinor: totalBalance),
    );
    var running = totalBalance;
    for (var i = 29; i >= 0; i--) {
      final day = today.subtract(Duration(days: 29 - i));
      balances[i] = DailyBalance(day: day, balanceMinor: running);
      running -= dayDeltas[day] ?? 0; // step back to the previous day's close
    }

    final spending = [
      for (final entry in categoryTotals.entries)
        CategorySpend(categoryId: entry.key, amountMinor: entry.value),
    ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));

    return DashboardSummary(
      totalBalanceMinor: totalBalance,
      todayExpenseMinor: todayExpense,
      monthIncomeMinor: monthIncome,
      monthExpenseMinor: monthExpense,
      owedToMeMinor: owedToMe,
      iOweMinor: iOwe,
      dailyBalances: balances,
      categorySpending: spending,
    );
  }
}
