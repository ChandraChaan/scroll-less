package dev.chandra.scroll_less.overlay

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import dev.chandra.scroll_less.MainActivity
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Floating counter drawn by the accessibility service itself using
 * TYPE_ACCESSIBILITY_OVERLAY. That window type needs no "display over other
 * apps" permission and is only visible while the service is enabled.
 *
 * The pill is draggable (position remembered) and a tap opens ScrollLess.
 */
class OverlayController(private val service: AccessibilityService) {
    private val prefs = service.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val wm = service.getSystemService(WindowManager::class.java)
    private var root: LinearLayout? = null
    private var countView: TextView? = null
    private var timeView: TextView? = null
    private var attached = false

    private val params = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.WRAP_CONTENT,
        WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        x = prefs.getInt(KEY_X, dp(12))
        y = prefs.getInt(KEY_Y, dp(96))
    }

    var enabled: Boolean
        get() = prefs.getBoolean(KEY_ENABLED, true)
        set(value) {
            prefs.edit().putBoolean(KEY_ENABLED, value).apply()
            if (!value) hide()
        }

    fun show() {
        if (!enabled || attached) return
        val view = root ?: build().also { root = it }
        try {
            wm.addView(view, params)
            attached = true
        } catch (_: Exception) {
            attached = false
        }
    }

    fun hide() {
        if (!attached) return
        try {
            root?.let { wm.removeView(it) }
        } catch (_: Exception) {
        }
        attached = false
    }

    fun update(count: Int, surfaceMs: Long, unit: String) {
        countView?.text = "$count $unit"
        timeView?.text = formatDuration(surfaceMs)
    }

    fun destroy() {
        hide()
        root = null
        countView = null
        timeView = null
    }

    private fun build(): LinearLayout {
        val ctx = service
        val pill = LinearLayout(ctx).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(14), dp(8), dp(14), dp(8))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(24).toFloat()
                setColor(Color.argb(215, 18, 18, 24))
                setStroke(dp(1), Color.argb(90, 255, 255, 255))
            }
            elevation = dp(6).toFloat()
        }
        val dot = View(ctx).apply {
            layoutParams = LinearLayout.LayoutParams(dp(8), dp(8)).apply { marginEnd = dp(8) }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.rgb(255, 92, 120))
            }
        }
        val count = TextView(ctx).apply {
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            typeface = Typeface.DEFAULT_BOLD
            text = "0"
        }
        val sep = TextView(ctx).apply {
            setTextColor(Color.argb(140, 255, 255, 255))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            text = "  ·  "
        }
        val time = TextView(ctx).apply {
            setTextColor(Color.argb(230, 255, 255, 255))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            text = "0m"
        }
        pill.addView(dot)
        pill.addView(count)
        pill.addView(sep)
        pill.addView(time)
        countView = count
        timeView = time
        installDrag(pill)
        return pill
    }

    private fun installDrag(view: View) {
        val slop = ViewConfiguration.get(service).scaledTouchSlop
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var moved = false
        view.setOnTouchListener { v, ev ->
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = ev.rawX; downY = ev.rawY
                    startX = params.x; startY = params.y
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = ev.rawX - downX
                    val dy = ev.rawY - downY
                    if (abs(dx) > slop || abs(dy) > slop) moved = true
                    if (moved) {
                        params.x = (startX + dx).roundToInt().coerceAtLeast(0)
                        params.y = (startY + dy).roundToInt().coerceAtLeast(0)
                        if (attached) runCatching { wm.updateViewLayout(v, params) }
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (moved) {
                        prefs.edit().putInt(KEY_X, params.x).putInt(KEY_Y, params.y).apply()
                    } else if (ev.actionMasked == MotionEvent.ACTION_UP) {
                        v.performClick()
                        openApp()
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun openApp() {
        val intent = Intent(service, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { service.startActivity(intent) }
    }

    private fun dp(v: Int): Int = (v * service.resources.displayMetrics.density).roundToInt()

    companion object {
        const val PREFS = "scrollless_prefs"
        const val KEY_ENABLED = "overlay_enabled"
        private const val KEY_X = "overlay_x"
        private const val KEY_Y = "overlay_y"

        fun formatDuration(ms: Long): String {
            val totalSec = ms / 1000
            val h = totalSec / 3600
            val m = (totalSec % 3600) / 60
            val s = totalSec % 60
            return when {
                h > 0 -> "${h}h ${m}m"
                m > 0 -> "${m}m"
                else -> "${s}s"
            }
        }
    }
}
