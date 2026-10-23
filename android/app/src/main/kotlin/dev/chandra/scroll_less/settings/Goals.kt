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
}
