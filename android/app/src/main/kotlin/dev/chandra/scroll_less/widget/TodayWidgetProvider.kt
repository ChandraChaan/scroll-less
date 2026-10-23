package dev.chandra.scroll_less.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import dev.chandra.scroll_less.MainActivity
import dev.chandra.scroll_less.R
import dev.chandra.scroll_less.data.StatsDatabase
import dev.chandra.scroll_less.detection.Targets
import dev.chandra.scroll_less.overlay.OverlayController
import dev.chandra.scroll_less.settings.Goals

/**
 * Home-screen widget. Three layouts (small 2×2, medium 3×2, large 4×3) are
 * chosen from the widget's current size, so every instance is resizable.
 * Two providers are registered so the launcher's picker offers a small and a
 * large default; both share this code.
 *
 * Refreshed by the accessibility service after every count and once a
 * minute while a tracked app is open, by the app when data or the goal
 * changes, and by the launcher every 30 minutes.
 */
open class TodayWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) update(context, appWidgetManager, id)
    }

    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
        update(context, appWidgetManager, appWidgetId)
    }

    companion object {
        enum class Size { SMALL, MEDIUM, LARGE }

        private val providers = listOf(TodayWidgetProvider::class.java, TodayWidgetLargeProvider::class.java)

        fun ids(context: Context): IntArray {
            val mgr = AppWidgetManager.getInstance(context)
            return providers.flatMap { mgr.getAppWidgetIds(ComponentName(context, it)).toList() }.toIntArray()
        }

        fun isAdded(context: Context): Boolean = ids(context).isNotEmpty()

        fun isPinSupported(context: Context): Boolean =
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                AppWidgetManager.getInstance(context).isRequestPinAppWidgetSupported

        /** Asks the launcher to show its "Add to home screen" sheet for the small or large widget. */
        fun requestPin(context: Context, large: Boolean): Boolean {
            if (!isPinSupported(context)) return false
            val mgr = AppWidgetManager.getInstance(context)
            val cls = if (large) TodayWidgetLargeProvider::class.java else TodayWidgetProvider::class.java
            return runCatching { mgr.requestPinAppWidget(ComponentName(context, cls), null, null) }.getOrDefault(false)
        }

        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            for (cls in providers) {
                for (id in mgr.getAppWidgetIds(ComponentName(context, cls))) update(context, mgr, id)
            }
        }

        private fun update(context: Context, mgr: AppWidgetManager, id: Int) {
            val today = StatsDatabase.today()
            val stats = StatsDatabase.get(context).statsForDay(today)
            val ig = stats.firstOrNull { it.pkg == Targets.INSTAGRAM }
            val yt = stats.firstOrNull { it.pkg == Targets.YOUTUBE }
            val week = StatsDatabase.get(context).history(7)
            val yesterdayKey = java.time.LocalDate.now().minusDays(1).toString()
            val data = Data(
                total = (ig?.reels ?: 0) + (yt?.reels ?: 0),
                igCount = ig?.reels ?: 0,
                ytCount = yt?.reels ?: 0,
                igMs = ig?.surfaceMs ?: 0L,
                ytMs = yt?.surfaceMs ?: 0L,
                goal = Goals.dailyGoal(context),
                yesterday = week.filter { it.day == yesterdayKey }.sumOf { it.reels },
                weekCount = week.sumOf { it.reels },
                weekMs = week.sumOf { it.surfaceMs },
            )
            val open = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )

            val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                RemoteViews(
                    mapOf(
                        SizeF(110f, 100f) to build(context, Size.SMALL, data, open),
                        SizeF(180f, 100f) to build(context, Size.MEDIUM, data, open),
                        SizeF(240f, 230f) to build(context, Size.LARGE, data, open),
                    ),
                )
            } else {
                val opts = mgr.getAppWidgetOptions(id)
                val w = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 180)
                val h = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 100)
                val size = when {
                    w >= 240 && h >= 230 -> Size.LARGE
                    w >= 180 -> Size.MEDIUM
                    else -> Size.SMALL
                }
                build(context, size, data, open)
            }
            mgr.updateAppWidget(id, views)
        }

        private class Data(
            val total: Int, val igCount: Int, val ytCount: Int, val igMs: Long, val ytMs: Long, val goal: Int,
            val yesterday: Int, val weekCount: Int, val weekMs: Long,
        )

        private fun build(context: Context, size: Size, d: Data, open: PendingIntent): RemoteViews {
            val layout = when (size) {
                Size.SMALL -> R.layout.widget_today_small
                Size.MEDIUM -> R.layout.widget_today
                Size.LARGE -> R.layout.widget_today_large
            }
            val views = RemoteViews(context.packageName, layout)
            val time = OverlayController.formatDuration(d.igMs + d.ytMs)
            views.setTextViewText(R.id.widget_count, d.total.toString())
            views.setTextViewText(R.id.widget_unit, if (d.total == 1) "short video" else "short videos")
            views.setTextViewText(R.id.widget_time, if (size == Size.LARGE) "$time scrolling" else time)
            views.setTextViewText(R.id.widget_label, if (d.goal > 0 && d.total > d.goal) "OVER GOAL" else "TODAY")

            if (d.goal > 0) {
                val pct = ((d.total * 100f) / d.goal).toInt().coerceIn(0, 100)
                views.setViewVisibility(R.id.widget_progress, View.VISIBLE)
                views.setProgressBar(R.id.widget_progress, 100, pct, false)
            } else {
                views.setViewVisibility(R.id.widget_progress, View.GONE)
            }

            when (size) {
                Size.SMALL -> {
                    views.setTextViewText(R.id.widget_detail, if (d.goal > 0) "${d.total} of ${d.goal} goal" else "IG ${d.igCount} · YT ${d.ytCount}")
                }
                Size.MEDIUM -> {
                    views.setTextViewText(
                        R.id.widget_detail,
                        "Instagram ${d.igCount}  ·  YouTube ${d.ytCount}" + if (d.goal > 0) "  ·  goal ${d.goal}" else "",
                    )
                }
                Size.LARGE -> {
                    views.setTextViewText(R.id.widget_ig, "${d.igCount} Reels · ${OverlayController.formatDuration(d.igMs)}")
                    views.setTextViewText(R.id.widget_yt, "${d.ytCount} Shorts · ${OverlayController.formatDuration(d.ytMs)}")
                    views.setTextViewText(R.id.widget_yesterday, "${d.yesterday} videos")
                    views.setTextViewText(R.id.widget_week, "${d.weekCount} videos · ${OverlayController.formatDuration(d.weekMs)}")
                    views.setTextViewText(
                        R.id.widget_goal,
                        when {
                            d.goal <= 0 -> ""
                            d.total > d.goal -> "${d.total - d.goal} over goal"
                            else -> "${d.goal - d.total} left of ${d.goal}"
                        },
                    )
                }
            }
            views.setOnClickPendingIntent(R.id.widget_root, open)
            return views
        }
    }
}

/** Same widget, registered separately so the picker offers a large default size. */
class TodayWidgetLargeProvider : TodayWidgetProvider()
