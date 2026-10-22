package dev.chandra.scroll_less.tracking

/**
 * Accumulates how long a tracked app has been in the foreground and how long
 * its Reels/Shorts surface has been on screen.
 *
 * Call [update] whenever the foreground state is observed (on events and on a
 * ~1 s tick). It returns the time elapsed since the previous observation,
 * attributed to the *previous* state, so the caller can add it to storage.
 * Gaps longer than [maxGapMs] are discarded: they mean we were not observing
 * (screen off, service paused) and must not be billed as scrolling.
 */
class UsageTracker(private val maxGapMs: Long = 15_000L) {

    data class Delta(val pkg: String, val foregroundMs: Long, val surfaceMs: Long)

    var activePackage: String? = null
        private set
    var onSurface: Boolean = false
        private set
    private var lastMs: Long = 0L

    fun update(pkg: String?, onSurface: Boolean, nowMs: Long): Delta? {
        val prevPkg = activePackage
        val prevSurface = this.onSurface
        val elapsed = if (prevPkg == null) 0L else (nowMs - lastMs).coerceAtLeast(0L)

        activePackage = pkg
        this.onSurface = pkg != null && onSurface
        lastMs = nowMs

        if (prevPkg == null || elapsed == 0L || elapsed > maxGapMs) return null
        return Delta(prevPkg, elapsed, if (prevSurface) elapsed else 0L)
    }

    /** Flush elapsed time without changing state. */
    fun tick(nowMs: Long): Delta? = update(activePackage, onSurface, nowMs)

    /** Leave whatever app was active; returns the final delta. */
    fun leave(nowMs: Long): Delta? = update(null, false, nowMs)
}
