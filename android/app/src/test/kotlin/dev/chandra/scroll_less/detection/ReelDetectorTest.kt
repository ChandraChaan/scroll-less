package dev.chandra.scroll_less.detection

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ReelDetectorTest {

    private val pkg = Targets.INSTAGRAM
    private fun fp(vararg tokens: String) = Fingerprint(tokens.toList())

    private fun snap(
        fingerprint: Fingerprint?,
        now: Long,
        index: Int? = null,
        onSurface: Boolean = true,
        p: String = pkg,
    ) = ReelDetector.Snapshot(p, onSurface, fingerprint, index, Confidence.HIGH, now)

    /** Drives the detector like the service does: snapshots plus a tick when a Pending deadline passes. */
    private class Harness(val detector: ReelDetector = ReelDetector(stableMs = 400, minIntervalMs = 500)) {
        val counted = ArrayList<ReelDetector.Decision.Counted>()
        var pendingAt: Long? = null

        fun feed(s: ReelDetector.Snapshot) = handle(detector.onSnapshot(s))

        fun tick(pkg: String, now: Long) {
            val at = pendingAt ?: return
            if (now >= at) handle(detector.onTick(pkg, now))
        }

        private fun handle(d: ReelDetector.Decision) {
            when (d) {
                is ReelDetector.Decision.Counted -> { counted.add(d); pendingAt = null }
                is ReelDetector.Decision.Pending -> pendingAt = d.readyAtMs
                ReelDetector.Decision.None -> pendingAt = null
            }
        }
    }

    @Test
    fun `first stable page counts once`() {
        val h = Harness()
        val a = fp("maya", "sunrise", "hampi")
        h.feed(snap(a, 1000))
        assertEquals(0, h.counted.size)
        h.feed(snap(a, 1200))
        assertEquals(0, h.counted.size)
        h.feed(snap(a, 1450))
        assertEquals(1, h.counted.size)
        h.feed(snap(a, 5000))
        h.feed(snap(a, 9000))
        assertEquals("same page must not count again", 1, h.counted.size)
    }

    @Test
    fun `pending page is committed by tick without new events`() {
        val h = Harness()
        h.feed(snap(fp("maya", "sunrise"), 1000))
        h.tick(pkg, 1300)
        assertEquals(0, h.counted.size)
        h.tick(pkg, 1500)
        assertEquals(1, h.counted.size)
    }

    @Test
    fun `genuine transitions count each new video`() {
        val h = Harness()
        val videos = listOf(
            fp("maya", "sunrise", "hampi"),
            fp("rohit", "leg", "finisher"),
            fp("chef", "garlic", "butter", "naan"),
        )
        var t = 1000L
        for (v in videos) {
            h.feed(snap(v, t)); t += 100
            h.feed(snap(v, t)); t += 400
            h.tick(pkg, t); t += 2000
        }
        assertEquals(3, h.counted.size)
        assertEquals(videos.map { it.key }, h.counted.map { it.fingerprint.key })
    }

    @Test
    fun `fast fling through intermediate pages counts only where the user lands`() {
        val h = Harness()
        val a = fp("maya", "sunrise", "hampi")
        h.feed(snap(a, 1000)); h.tick(pkg, 1500)
        assertEquals(1, h.counted.size)
        // Fling: pages b, c, d each visible < stableMs
        h.feed(snap(fp("b1", "b2", "b3"), 3000))
        h.feed(snap(fp("c1", "c2", "c3"), 3150))
        h.feed(snap(fp("d1", "d2", "d3"), 3300))
        val e = fp("e1", "e2", "e3")
        h.feed(snap(e, 3450))
        h.tick(pkg, 3700) // b/c/d never stable
        assertEquals(1, h.counted.size)
        h.tick(pkg, 3900)
        assertEquals(2, h.counted.size)
        assertEquals(e.key, h.counted.last().fingerprint.key)
    }

    @Test
    fun `caption expansion on the same video does not count`() {
        val h = Harness()
        val collapsed = fp("maya", "sunrise", "hampi")
        val expanded = fp("maya", "sunrise", "hampi", "boulders", "india", "travel", "goldenhour")
        h.feed(snap(collapsed, 1000)); h.tick(pkg, 1500)
        h.feed(snap(expanded, 2000)); h.tick(pkg, 2500)
        h.feed(snap(expanded, 3000))
        assertEquals(1, h.counted.size)
    }

    @Test
    fun `scrolling back to a recently watched video is not counted twice`() {
        val h = Harness()
        val a = fp("maya", "sunrise", "hampi")
        val b = fp("rohit", "leg", "finisher")
        h.feed(snap(a, 1000, index = 0)); h.tick(pkg, 1500)
        h.feed(snap(b, 3000, index = 1)); h.tick(pkg, 3500)
        h.feed(snap(a, 5000, index = 0)); h.tick(pkg, 5500)
        assertEquals(2, h.counted.size)
        // ...and moving forward again to b is also a duplicate
        h.feed(snap(b, 7000, index = 1)); h.tick(pkg, 7500)
        assertEquals(2, h.counted.size)
        // but a brand-new video c counts
        h.feed(snap(fp("chef", "garlic", "naan"), 9000, index = 2)); h.tick(pkg, 9500)
        assertEquals(3, h.counted.size)
    }

    @Test
    fun `pager index change overrides similar fingerprints`() {
        val h = Harness()
        // Two videos from the same creator with no caption: texts almost identical.
        val a = fp("maya", "goa")
        val b = fp("maya", "goa")
        h.feed(snap(a, 1000, index = 4)); h.tick(pkg, 1500)
        h.feed(snap(b, 3000, index = 5)); h.tick(pkg, 3500)
        assertEquals(2, h.counted.size)
    }

    @Test
    fun `leaving the surface and coming back to the same video does not double count`() {
        val h = Harness()
        val a = fp("maya", "sunrise", "hampi")
        h.feed(snap(a, 1000)); h.tick(pkg, 1500)
        h.feed(snap(null, 2000, onSurface = false))
        h.feed(snap(a, 4000)); h.tick(pkg, 4500)
        assertEquals(1, h.counted.size)
    }

    @Test
    fun `off-surface snapshots never count`() {
        val h = Harness()
        h.feed(snap(fp("feed", "post", "text"), 1000, onSurface = false))
        h.tick(pkg, 2000)
        assertTrue(h.counted.isEmpty())
    }

    @Test
    fun `empty fingerprints are ignored`() {
        val h = Harness()
        h.feed(snap(Fingerprint(emptyList()), 1000))
        h.feed(snap(null, 1100))
        h.tick(pkg, 2000)
        assertTrue(h.counted.isEmpty())
    }

    @Test
    fun `packages are tracked independently`() {
        val h = Harness()
        val same = fp("maya", "sunrise", "hampi")
        h.feed(snap(same, 1000, p = Targets.INSTAGRAM)); h.tick(Targets.INSTAGRAM, 1500)
        h.feed(snap(same, 2000, p = Targets.YOUTUBE)); h.tick(Targets.YOUTUBE, 2500)
        assertEquals(2, h.counted.size)
        assertEquals(setOf(Targets.INSTAGRAM, Targets.YOUTUBE), h.counted.map { it.pkg }.toSet())
    }

    @Test
    fun `rate limit suppresses bursts`() {
        val h = Harness(ReelDetector(stableMs = 0, minIntervalMs = 500))
        h.feed(snap(fp("a1", "a2"), 1000)); h.tick(pkg, 1000)
        h.feed(snap(fp("b1", "b2"), 1100)); h.tick(pkg, 1100)
        h.feed(snap(fp("c1", "c2"), 1700)); h.tick(pkg, 1700)
        assertEquals(2, h.counted.size)
    }
}
