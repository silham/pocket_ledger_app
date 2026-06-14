/// Bridges this month's overall-budget figures to the Android home-screen
/// widget (see android/.../BudgetWidgetProvider.kt) and defines the deep links
/// the widget uses (card -> Budgets, "+ Add" -> quick-add).
///
/// Data only flows out while the app process is alive: we push the latest
/// figures whenever the budget summary changes (see app.dart). The widget
/// keeps showing the last pushed values after the app is closed.
library;

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../money/money.dart';
import '../../features/more/budgets/budgets_screen.dart' show BudgetLine;

class HomeWidgetService {
  HomeWidgetService._();

  /// Fully-qualified provider class — must match the Kotlin package + class.
  static const _androidProvider =
      'net.webloomlabs.pocket_ledger_app.BudgetWidgetProvider';

  /// URIs the widget launches the app with; matched in app.dart to route.
  static final addTransactionUri = Uri.parse('pocketledger://add');
  static final budgetsUri = Uri.parse('pocketledger://budgets');

  static final _dayFormat = DateFormat('MMM d');

  /// Push the current month's overall budget to the widget and redraw it.
  /// [overall] is null when no overall budget is set for the month.
  static Future<void> updateBudget({
    required BudgetLine? overall,
    required DateTime now,
  }) async {
    if (overall == null) {
      await _saveEmpty();
    } else {
      await _saveBudget(overall, now);
    }
    await HomeWidget.updateWidget(qualifiedAndroidName: _androidProvider);
  }

  static Future<void> _saveBudget(BudgetLine overall, DateTime now) async {
    final budget = overall.amountMinor;
    final spent = overall.spentMinor;
    final remaining = budget - spent;
    final percent = budget == 0 ? 0 : (spent / budget * 100).round();

    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0); // last day of month
    // Days left including today.
    final daysRemaining = monthEnd.day - now.day + 1;

    final String footer;
    if (remaining <= 0) {
      footer = 'Over budget by ${formatMinor(-remaining)}';
    } else if (daysRemaining > 0) {
      final perDay = remaining ~/ daysRemaining;
      footer = 'You can spend ${formatMinor(perDay)}/day '
          'for $daysRemaining more ${daysRemaining == 1 ? 'day' : 'days'}';
    } else {
      footer = '${formatMinor(remaining)} left';
    }

    await Future.wait([
      HomeWidget.saveWidgetData<String>('budget_left', formatMinor(remaining)),
      HomeWidget.saveWidgetData<String>(
          'budget_of', 'left of ${formatMinor(budget)}'),
      HomeWidget.saveWidgetData<String>('budget_percent_text', '$percent%'),
      HomeWidget.saveWidgetData<String>('budget_percent', '$percent'),
      HomeWidget.saveWidgetData<String>(
          'budget_start', _dayFormat.format(monthStart)),
      HomeWidget.saveWidgetData<String>(
          'budget_end', _dayFormat.format(monthEnd)),
      HomeWidget.saveWidgetData<String>('budget_footer', footer),
    ]);
  }

  static Future<void> _saveEmpty() => Future.wait([
        HomeWidget.saveWidgetData<String>('budget_left', '—'),
        HomeWidget.saveWidgetData<String>('budget_of', ''),
        HomeWidget.saveWidgetData<String>('budget_percent_text', ''),
        HomeWidget.saveWidgetData<String>('budget_percent', '0'),
        HomeWidget.saveWidgetData<String>('budget_start', ''),
        HomeWidget.saveWidgetData<String>('budget_end', ''),
        HomeWidget.saveWidgetData<String>(
            'budget_footer', 'Tap to set a monthly budget'),
      ]);
}
