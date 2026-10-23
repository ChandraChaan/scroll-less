package dev.chandra.scroll_less.settings

import android.content.Context
import dev.chandra.scroll_less.overlay.OverlayController

/** Daily goal (max short videos per day). 0 means no goal. Stored locally only. */
object Goals {
    private const val KEY = "daily_goal"

    fun dailyGoal(context: Context): Int =
        context.getSharedPreferences(OverlayController.PREFS, Context.MODE_PRIVATE).getInt(KEY, 0)

    fun setDailyGoal(context: Context, goal: Int) {
        context.getSharedPreferences(OverlayController.PREFS, Context.MODE_PRIVATE)
            .edit().putInt(KEY, goal.coerceIn(0, 1000)).apply()
    }

    private const val KEY_MIN_WATCH = "min_watch_ms"

    /** Minimum on-screen time before a video counts (500 ms – 10 s). */
    fun minWatchMs(context: Context): Long =
        context.getSharedPreferences(OverlayController.PREFS, Context.MODE_PRIVATE)
            .getLong(KEY_MIN_WATCH, dev.chandra.scroll_less.detection.ReelDetector.DEFAULT_STABLE_MS)

    fun setMinWatchMs(context: Context, ms: Long) {
        context.getSharedPreferences(OverlayController.PREFS, Context.MODE_PRIVATE)
            .edit().putLong(KEY_MIN_WATCH, ms.coerceIn(500L, 10_000L)).apply()
    }
}
