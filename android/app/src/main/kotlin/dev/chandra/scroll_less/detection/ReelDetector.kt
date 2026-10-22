package dev.chandra.scroll_less.detection

/**
 * Turns a stream of window snapshots into "a new video was watched" events.
 *
 * Counting rules (all tunable through the constructor):
 *  - A new page must stay on screen for [stableMs] before it counts. Pages that
 *    fly past during a fast fling never stabilise and are never counted.
 *  - A page is "the same" as the current one when the pager index (if known)
 *    is unchanged and the fingerprint overlap is at least [sameThreshold]. This
 *    absorbs caption expansion, counters ticking, and other content drift.
 *  - Pages whose fingerprint overlaps a recently counted page at
 *    [duplicateThreshold] or more (same index, if known) are duplicates:
 *    scrolling back up to a video you already watched does not count again.
 *  - Counts are rate limited to one per [minIntervalMs] as a last line of
 *    defence against event storms.
 *
 * State is kept per package so Instagram and YouTube never interfere.
 * The class is pure Kotlin: feed it [Snapshot]s and call [onTick] when a
 * [Decision.Pending] deadline passes.
 */
class ReelDetector(
    private val stableMs: Long = 400L,
    private val minIntervalMs: Long = 500L,
    private val recentSize: Int = 60,
    private val sameThreshold: Double = 0.6,
    private val duplicateThreshold: Double = 0.85,
) {
    data class Snapshot(
        val pkg: String,
        val onSurface: Boolean,
        val fingerprint: Fingerprint?,
        val pageIndex: Int?,
        val confidence: Confidence,
        val nowMs: Long,
    )

    sealed interface Decision {
        data class Counted(
            val pkg: String,
            val fingerprint: Fingerprint,
            val pageIndex: Int?,
            val confidence: Confidence,
            val atMs: Long,
        ) : Decision

        /** A candidate page is on screen; call [onTick] at or after [readyAtMs]. */
        data class Pending(val readyAtMs: Long) : Decision

        data object None : Decision
    }

    private class Entry(val fp: Fingerprint, val index: Int?)

    private class PkgState(val pkg: String) {
        var current: Entry? = null
        var pending: Entry? = null
        var pendingSince: Long = 0L
        var pendingConfidence: Confidence = Confidence.NONE
        val recent = ArrayDeque<Entry>()
        var lastCountMs: Long = Long.MIN_VALUE / 2
    }

    private val states = HashMap<String, PkgState>()

    /** Forget the current/pending page (e.g. app went to background) but keep the duplicate history. */
    fun leaveSurface(pkg: String) {
        states[pkg]?.let {
            it.current = null
            it.pending = null
        }
    }

    /** Drop everything known about [pkg], including duplicate history. */
    fun reset(pkg: String) {
        states.remove(pkg)
    }

    fun onSnapshot(s: Snapshot): Decision {
        val st = states.getOrPut(s.pkg) { PkgState(s.pkg) }
        if (!s.onSurface) {
            st.current = null
            st.pending = null
            return Decision.None
        }
        val fp = s.fingerprint
        if (fp == null || fp.isEmpty) {
            // Can't identify what's on screen; keep whatever state we had.
            return st.pending?.let { Decision.Pending(st.pendingSince + stableMs) } ?: Decision.None
        }

        st.pending?.let { pend ->
            return if (isSame(pend, fp, s.pageIndex)) {
                st.pending = Entry(fp, s.pageIndex ?: pend.index)
                if (s.nowMs - st.pendingSince >= stableMs) commit(st, s.nowMs) else Decision.Pending(st.pendingSince + stableMs)
            } else {
                // The candidate changed before it stabilised (fling in progress): restart the clock.
                startPending(st, fp, s.pageIndex, s.confidence, s.nowMs)
            }
        }

        val cur = st.current
        if (cur != null && isSame(cur, fp, s.pageIndex)) {
            // Same video, content drifted a little (caption expanded, counters moved).
            st.current = Entry(fp, s.pageIndex ?: cur.index)
            return Decision.None
        }
        return startPending(st, fp, s.pageIndex, s.confidence, s.nowMs)
    }

    /** Re-evaluate a pending candidate without new window content. */
    fun onTick(pkg: String, nowMs: Long): Decision {
        val st = states[pkg] ?: return Decision.None
        st.pending ?: return Decision.None
        return if (nowMs - st.pendingSince >= stableMs) commit(st, nowMs) else Decision.Pending(st.pendingSince + stableMs)
    }

    private fun startPending(st: PkgState, fp: Fingerprint, index: Int?, confidence: Confidence, nowMs: Long): Decision {
        st.pending = Entry(fp, index)
        st.pendingSince = nowMs
        st.pendingConfidence = confidence
        return Decision.Pending(nowMs + stableMs)
    }

    private fun isSame(e: Entry, fp: Fingerprint, index: Int?): Boolean {
        if (e.index != null && index != null && e.index != index) return false
        return e.fp.similarity(fp) >= sameThreshold
    }

    private fun commit(st: PkgState, nowMs: Long): Decision {
        val entry = st.pending ?: return Decision.None
        val confidence = st.pendingConfidence
        st.pending = null
        st.current = entry

        val duplicate = st.recent.any { r ->
            (r.index == null || entry.index == null || r.index == entry.index) &&
                r.fp.similarity(entry.fp) >= duplicateThreshold
        }
        if (duplicate) return Decision.None

        st.recent.addLast(entry)
        while (st.recent.size > recentSize) st.recent.removeFirst()

        if (nowMs - st.lastCountMs < minIntervalMs) return Decision.None
        st.lastCountMs = nowMs
        return Decision.Counted(st.pkg, entry.fp, entry.index, confidence, nowMs)
    }
}
