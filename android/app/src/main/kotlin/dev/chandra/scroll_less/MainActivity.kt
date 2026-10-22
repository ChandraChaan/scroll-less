package dev.chandra.scroll_less

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import dev.chandra.scroll_less.data.StatsBus
import dev.chandra.scroll_less.data.StatsDatabase
import dev.chandra.scroll_less.overlay.OverlayController
import dev.chandra.scroll_less.service.ScrollLessAccessibilityService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var busListener: StatsBus.Listener? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val db = StatsDatabase.get(this)
        db.writableDatabase // make sure the schema exists before Flutter opens the file

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())
                    "isServiceRunning" -> result.success(ScrollLessAccessibilityService.isRunning)
                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(null)
                    }
                    "getOverlayEnabled" -> result.success(
                        getSharedPreferences(OverlayController.PREFS, Context.MODE_PRIVATE)
                            .getBoolean(OverlayController.KEY_ENABLED, true),
                    )
                    "setOverlayEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        getSharedPreferences(OverlayController.PREFS, Context.MODE_PRIVATE)
                            .edit().putBoolean(OverlayController.KEY_ENABLED, enabled).apply()
                        ScrollLessAccessibilityService.instance?.onOverlayPreferenceChanged()
                        result.success(null)
                    }
                    "getTodayStats" -> result.success(db.statsForDay(StatsDatabase.today()).map { it.toMap() })
                    "getHistory" -> result.success(db.history(call.argument<Int>("days") ?: 7).map { it.toMap() })
                    "getRecentEvents" -> result.success(db.recentEvents(call.argument<Int>("limit") ?: 20).map { it.toMap() })
                    "resetToday" -> { db.resetDay(StatsDatabase.today()); result.success(null) }
                    "clearAllData" -> { db.clearAll(); result.success(null) }
                    "getDatabaseName" -> result.success(StatsDatabase.NAME)
                    "testCrash" -> {
                        // Deliberate native crash so Crashlytics reporting can be verified end to end.
                        Handler(Looper.getMainLooper()).post { throw RuntimeException("ScrollLess test crash (intentional)") }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("native_error", e.message, null)
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    val l = StatsBus.Listener { payload -> events.success(payload) }
                    busListener = l
                    StatsBus.subscribe(l)
                    if (StatsBus.last == null) {
                        events.success(
                            mapOf(
                                "day" to StatsDatabase.today(),
                                "serviceRunning" to ScrollLessAccessibilityService.isRunning,
                                "activePackage" to null,
                                "onSurface" to false,
                                "stats" to db.statsForDay(StatsDatabase.today()).map { it.toMap() },
                            ),
                        )
                    }
                }

                override fun onCancel(arguments: Any?) {
                    busListener?.let { StatsBus.unsubscribe(it) }
                    busListener = null
                }
            },
        )
    }

    private fun isAccessibilityEnabled(): Boolean {
        val expected = ComponentName(this, ScrollLessAccessibilityService::class.java)
        val enabled = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        for (name in splitter) {
            val cn = ComponentName.unflattenFromString(name) ?: continue
            if (cn == expected) return true
        }
        return false
    }

    override fun onDestroy() {
        busListener?.let { StatsBus.unsubscribe(it) }
        super.onDestroy()
    }

    companion object {
        const val METHOD_CHANNEL = "dev.chandra.scroll_less/native"
        const val EVENT_CHANNEL = "dev.chandra.scroll_less/stats"
    }
}
