package dev.chandra.scroll_less.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import dev.chandra.scroll_less.MainActivity
import dev.chandra.scroll_less.R
import dev.chandra.scroll_less.data.StatsDatabase
import dev.chandra.scroll_less.detection.Targets
import dev.chandra.scroll_less.overlay.OverlayController
import dev.chandra.scroll_less.settings.Goals

/**
 * Home-screen widget: today's total, per-app split, scrolling time and the
 * daily-goal progress. Refreshed by the accessibility service after every
 * count and once a minute while a tracked app is open, by the app when data
 * or the goal changes, and by the launcher every 30 minutes.
 */
class TodayWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) update(context, appWidgetManager, id)
    }

    companion object {
        private fun component(context: Context) = ComponentName(context, TodayWidgetProvider::class.java)

        fun ids(context: Context): IntArray =
            AppWidgetManager.getInstance(context).getAppWidgetIds(component(context))

        fun isAdded(context: Context): Boolean = ids(context).isNotEmpty()

        fun isPinSupported(context: Context): Boolean =
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                AppWidgetManager.getInstance(context).isRequestPinAppWidgetSupported

        /** Asks the launcher to show its "Add to home screen" sheet. Returns false if unsupported. */
        fun requestPin(context: Context): Boolean {
            if (!isPinSupported(context)) return false
            val mgr = AppWidgetManager.getInstance(context)
            return runCatching { mgr.requestPinAppWidget(component(context), null, null) }.getOrDefault(false)
        }

        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            for (id in mgr.getAppWidgetIds(component(context))) update(context, mgr, id)
        }

        private fun update(context: Context, mgr: AppWidgetManager, id: Int) {
            val today = StatsDatabase.today()
            val stats = StatsDatabase.get(context).statsForDay(today)
            val ig = stats.firstOrNull { it.pkg == Targets.INSTAGRAM }
            val yt = stats.firstOrNull { it.pkg == Targets.YOUTUBE }
            val total = (ig?.reels ?: 0) + (yt?.reels ?: 0)
            val surfaceMs = (ig?.surfaceMs ?: 0L) + (yt?.surfaceMs ?: 0L)
            val goal = Goals.dailyGoal(context)

            val views = RemoteViews(context.packageName, R.layout.widget_today)
            views.setTextViewText(R.id.widget_count, total.toString())
            views.setTextViewText(R.id.widget_unit, if (total == 1) "short video" else "short videos")
            views.setTextViewText(R.id.widget_time, OverlayController.formatDuration(surfaceMs))
            views.setTextViewText(
                R.id.widget_detail,
                "Instagram ${ig?.reels ?: 0}  ·  YouTube ${yt?.reels ?: 0}" + if (goal > 0) "  ·  goal $goal" else "",
            )
            if (goal > 0) {
                val pct = ((total * 100f) / goal).toInt().coerceIn(0, 100)
                views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
                views.setProgressBar(R.id.widget_progress, 100, pct, false)
                views.setTextViewText(R.id.widget_label, if (total > goal) "OVER GOAL" else "TODAY")
            } else {
                views.setViewVisibility(R.id.widget_progress, View.GONE)
                views.setTextViewText(R.id.widget_label, "TODAY")
            }

            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setOnClickPendingIntent(R.id.widget_root, open)
            mgr.updateAppWidget(id, views)
        }
    }
}
