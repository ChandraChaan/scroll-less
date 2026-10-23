package dev.chandra.scroll_less.service

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import dev.chandra.scroll_less.data.StatsBus
import dev.chandra.scroll_less.data.StatsDatabase
import dev.chandra.scroll_less.detection.AccessibilityUiNode
import dev.chandra.scroll_less.detection.FingerprintBuilder
import dev.chandra.scroll_less.detection.ReelDetector
import dev.chandra.scroll_less.detection.SurfaceClassifier
import dev.chandra.scroll_less.detection.Targets
import dev.chandra.scroll_less.overlay.OverlayController
import dev.chandra.scroll_less.settings.Goals
import dev.chandra.scroll_less.tracking.UsageTracker
import dev.chandra.scroll_less.widget.TodayWidgetProvider

/**
 * The heart of ScrollLess.
 *
 * Receives window events for Instagram and YouTube, classifies whether the
 * Reels/Shorts viewer is on screen, fingerprints the current page and hands
 * everything to [ReelDetector]. Also times how long each app (and its
 * short-video surface) is in the foreground and keeps the floating counter
 * up to date. All state is stored in a local SQLite database.
 *
 * Window content of apps other than Instagram and YouTube is never read; for
 * them only the fact that a *different* app came to the foreground is used to
 * stop the timers.
 */
class ScrollLessAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var db: StatsDatabase
    private lateinit var overlay: OverlayController
    private lateinit var classifier: SurfaceClassifier
    private val detector = ReelDetector()
    private val usage = UsageTracker()

    private var activePkg: String? = null
    private var activeOnSurface = false
    private var lastPublishMs = 0L
    private var connectedAtMs = 0L
    private var lastWidgetMs = 0L

    private val processRunnable = Runnable { process() }
    private val pendingRunnable = Runnable { settlePending() }
    private val tickRunnable = object : Runnable {
        override fun run() {
            tick()
            if (activePkg != null) handler.postDelayed(this, TICK_MS)
        }
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == Intent.ACTION_SCREEN_OFF) leave()
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        connectedAtMs = SystemClock.elapsedRealtime()
        db = StatsDatabase.get(this)
        overlay = OverlayController(this)
        val dm = resources.displayMetrics
        classifier = SurfaceClassifier(dm.widthPixels, dm.heightPixels)

        serviceInfo = (serviceInfo ?: AccessibilityServiceInfo()).apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOWS_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                AccessibilityEvent.TYPE_VIEW_SCROLLED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = flags or AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
            notificationTimeout = 50
        }
        registerReceiver(screenReceiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
        publish()
        Log.i(TAG, "ScrollLess accessibility service connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val pkg = event.packageName?.toString() ?: return
        if (pkg in Targets.ALL) {
            if (activePkg != pkg) {
                // A picture-in-picture or minimised window of Instagram/YouTube still emits
                // events while another app is in front; only count it as "entered" when it
                // really is the active window.
                val active = rootInActiveWindow?.packageName?.toString()
                if (active != null && active != pkg) return
                enterApp(pkg)
            }
            handler.removeCallbacks(processRunnable)
            handler.postDelayed(processRunnable, DEBOUNCE_MS)
        } else if (activePkg != null) {
            when (event.eventType) {
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                    if (pkg in IGNORED_PACKAGES) return
                    if (pkg == packageName && event.className?.toString()?.contains("Activity") != true) return
                    leave()
                }
                AccessibilityEvent.TYPE_WINDOWS_CHANGED -> checkStillInForeground()
                else -> Unit
            }
        }
    }

    /**
     * Some Android versions do not emit TYPE_WINDOW_STATE_CHANGED when the launcher or a
     * previous task comes back to the front. Verify against the active window itself.
     */
    private fun checkStillInForeground() {
        val active = activePkg ?: return
        val current = rootInActiveWindow?.packageName?.toString() ?: return
        if (current == active || current in IGNORED_PACKAGES) return
        if (current == packageName) return // our own overlay / activity windows are handled by state events
        leave()
    }

    override fun onInterrupt() {}

    override fun onUnbind(intent: Intent?): Boolean {
        shutdown()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        shutdown()
        super.onDestroy()
    }

    private fun shutdown() {
        leave()
        handler.removeCallbacksAndMessages(null)
        runCatching { unregisterReceiver(screenReceiver) }
        if (::overlay.isInitialized) overlay.destroy()
        if (instance === this) instance = null
        publish()
    }

    // ---------------------------------------------------------------- state

    private fun enterApp(pkg: String) {
        val now = SystemClock.elapsedRealtime()
        if (now - connectedAtMs < RESTART_GRACE_MS) {
            // Service just (re)started while the user may already be mid-video: if we counted
            // something for this app moments ago, don't count the page on screen again.
            val lastTs = db.lastEventTs(pkg)
            if (lastTs != null && System.currentTimeMillis() - lastTs < RESTART_RECOUNT_WINDOW_MS) {
                detector.adoptNextWithoutCounting(pkg)
            }
        }
        applyUsage(now)
        activePkg = pkg
        activeOnSurface = false
        usage.update(pkg, false, now)
        handler.removeCallbacks(tickRunnable)
        handler.postDelayed(tickRunnable, TICK_MS)
        refreshOverlay(pkg)
        overlay.show()
    }

    private fun leave() {
        val pkg = activePkg ?: return
        val now = SystemClock.elapsedRealtime()
        applyUsage(now)
        usage.leave(now)
        detector.leaveSurface(pkg)
        activePkg = null
        activeOnSurface = false
        handler.removeCallbacks(tickRunnable)
        handler.removeCallbacks(processRunnable)
        handler.removeCallbacks(pendingRunnable)
        if (::overlay.isInitialized) overlay.hide()
        publish(force = true)
        refreshWidget(force = true)
    }

    private fun process() {
        val pkg = activePkg ?: return
        val root = rootInActiveWindow ?: return
        if (root.packageName?.toString() != pkg) return // keyboard / system window on top

        val now = SystemClock.elapsedRealtime()
        val result = try {
            classifier.classify(AccessibilityUiNode(root), pkg)
        } catch (e: Exception) {
            Log.w(TAG, "classify failed", e)
            return
        }
        val page = result.currentPage
        val fingerprint = page?.let { FingerprintBuilder.build(it) }
        val index = page?.collectionItemIndex

        activeOnSurface = result.onSurface
        applyUsage(now)

        val decision = detector.onSnapshot(
            ReelDetector.Snapshot(pkg, result.onSurface, fingerprint, index, result.confidence, now),
        )
        handleDecision(pkg, decision)
        refreshOverlay(pkg)
        publish()
    }

    private fun settlePending() {
        val pkg = activePkg ?: return
        val decision = detector.onTick(pkg, SystemClock.elapsedRealtime())
        handleDecision(pkg, decision)
        refreshOverlay(pkg)
    }

    private fun handleDecision(pkg: String, decision: ReelDetector.Decision) {
        when (decision) {
            is ReelDetector.Decision.Counted -> {
                db.recordReel(
                    StatsDatabase.today(),
                    pkg,
                    System.currentTimeMillis(),
                    decision.fingerprint.key,
                    decision.confidence.name,
                )
                Log.d(TAG, "counted ${Targets.unitLabel(pkg)} ${decision.fingerprint.key} (${decision.confidence})")
                publish(force = true)
                refreshWidget(force = true)
            }
            is ReelDetector.Decision.Pending -> {
                handler.removeCallbacks(pendingRunnable)
                val delay = (decision.readyAtMs - SystemClock.elapsedRealtime()).coerceAtLeast(0L) + 10L
                handler.postDelayed(pendingRunnable, delay)
            }
            ReelDetector.Decision.None -> Unit
        }
    }

    private fun tick() {
        checkStillInForeground()
        if (activePkg == null) return
        applyUsage(SystemClock.elapsedRealtime())
        activePkg?.let { refreshOverlay(it) }
        publish()
        refreshWidget()
    }

    private fun refreshWidget(force: Boolean = false) {
        val now = SystemClock.elapsedRealtime()
        if (!force && now - lastWidgetMs < WIDGET_MIN_INTERVAL_MS) return
        lastWidgetMs = now
        runCatching { TodayWidgetProvider.updateAll(this) }
    }

    private fun applyUsage(now: Long) {
        val delta = usage.update(activePkg, activeOnSurface, now) ?: return
        db.addUsage(StatsDatabase.today(), delta.pkg, delta.foregroundMs, delta.surfaceMs)
    }

    private fun refreshOverlay(pkg: String) {
        if (!overlay.enabled) return
        val stats = db.statsForDay(StatsDatabase.today())
        val stat = stats.firstOrNull { it.pkg == pkg }
        val total = stats.sumOf { it.reels }
        overlay.update(stat?.reels ?: 0, stat?.surfaceMs ?: 0L, Targets.unitLabel(pkg), total, Goals.dailyGoal(this))
    }

    private fun publish(force: Boolean = false) {
        val now = SystemClock.elapsedRealtime()
        if (!force && now - lastPublishMs < 900) return
        lastPublishMs = now
        val today = StatsDatabase.today()
        StatsBus.publish(
            mapOf(
                "day" to today,
                "serviceRunning" to (instance != null),
                "activePackage" to activePkg,
                "onSurface" to activeOnSurface,
                "stats" to db.statsForDay(today).map { it.toMap() },
            ),
        )
    }

    fun onOverlayPreferenceChanged() {
        if (overlay.enabled) {
            activePkg?.let { refreshOverlay(it); overlay.show() }
        } else {
            overlay.hide()
        }
    }

    companion object {
        private const val TAG = "ScrollLess"
        private const val DEBOUNCE_MS = 60L
        private const val TICK_MS = 1000L
        private const val RESTART_GRACE_MS = 15_000L
        private const val RESTART_RECOUNT_WINDOW_MS = 90_000L
        private const val WIDGET_MIN_INTERVAL_MS = 60_000L
        private val IGNORED_PACKAGES = setOf(
            "com.android.systemui",
            "android",
            "com.google.android.inputmethod.latin",
            "com.google.android.permissioncontroller",
            "com.android.permissioncontroller",
        )

        @Volatile var instance: ScrollLessAccessibilityService? = null
            private set

        val isRunning: Boolean get() = instance != null
    }
}
