package net.webloomlabs.pocket_ledger_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing this month's overall budget (amount left, a
 * progress bar, and how much is spendable per day) with a "+ Add transaction"
 * button below.
 *
 * Values come from the Flutter side via HomeWidget.saveWidgetData (see
 * lib/core/widget/home_widget_service.dart); `widgetData` is that shared store.
 */
class BudgetWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.budget_widget).apply {
                setTextViewText(R.id.budget_left, widgetData.getString("budget_left", "—"))
                setTextViewText(R.id.budget_of, widgetData.getString("budget_of", ""))
                setTextViewText(R.id.budget_percent, widgetData.getString("budget_percent_text", ""))
                setTextViewText(R.id.budget_start, widgetData.getString("budget_start", ""))
                setTextViewText(R.id.budget_end, widgetData.getString("budget_end", ""))
                setTextViewText(
                    R.id.budget_footer,
                    widgetData.getString("budget_footer", "Tap to set a monthly budget"),
                )

                val percent = (widgetData.getString("budget_percent", "0") ?: "0")
                    .toIntOrNull() ?: 0
                setProgressBar(R.id.budget_progress, 100, percent.coerceIn(0, 100), false)

                // Tap the card body -> open the Budgets screen.
                setOnClickPendingIntent(
                    R.id.budget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("pocketledger://budgets"),
                    ),
                )

                // Tap "+ Add transaction" -> open the quick-add flow.
                setOnClickPendingIntent(
                    R.id.budget_add_button,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("pocketledger://add"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
