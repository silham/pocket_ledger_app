/// Bridges the app's "spent today" figure to the Android home-screen widget
/// (see android/.../SpendingWidgetProvider.kt) and defines the deep link the
/// widget's "+ Add" button uses to open the quick-add flow.
///
/// Data only flows out while the app process is alive: we push the latest
/// figure whenever the dashboard summary changes (see app.dart). The widget
/// keeps showing the last pushed value after the app is closed.
library;

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../money/money.dart';

class HomeWidgetService {
  HomeWidgetService._();

  /// Fully-qualified provider class — must match the Kotlin package + class.
  static const _androidProvider =
      'net.webloomlabs.pocket_ledger_app.SpendingWidgetProvider';

  // Keys the Kotlin provider reads out of the shared widget store.
  static const _amountKey = 'today_spent';
  static const _dateKey = 'today_date';

  /// URI the widget's "+ Add" button launches the app with. Matched in
  /// app.dart to route to the quick-add transaction screen.
  static final Uri addTransactionUri = Uri.parse('pocketledger://add');

  static final _dateFormat = DateFormat('EEE, d MMM');

  /// Push today's expense total to the widget and ask it to redraw.
  static Future<void> updateDailySpending({
    required int todayExpenseMinor,
    required DateTime now,
  }) async {
    await HomeWidget.saveWidgetData<String>(
      _amountKey,
      formatMinor(todayExpenseMinor),
    );
    await HomeWidget.saveWidgetData<String>(_dateKey, _dateFormat.format(now));
    await HomeWidget.updateWidget(qualifiedAndroidName: _androidProvider);
  }
}
