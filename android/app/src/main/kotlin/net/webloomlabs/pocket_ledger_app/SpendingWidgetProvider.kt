package net.webloomlabs.pocket_ledger_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing how much was spent today, with a "+ Add" button
 * that deep-links into the quick-add transaction flow.
 *
 * Values come from the Flutter side via HomeWidget.saveWidgetData (see
 * lib/core/widget/home_widget_service.dart); `widgetData` is that shared store.
 */
class SpendingWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.spending_widget).apply {
                val amount = widgetData.getString("today_spent", null) ?: "Rs. 0.00"
                val date = widgetData.getString("today_date", null) ?: "Today"
                setTextViewText(R.id.widget_amount, amount)
                setTextViewText(R.id.widget_date, date)

                // Tap the card body -> just open the app (dashboard).
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )

                // Tap "+ Add" -> open the quick-add transaction flow.
                setOnClickPendingIntent(
                    R.id.widget_add_button,
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
