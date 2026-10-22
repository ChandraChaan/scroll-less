package dev.chandra.scroll_less.tracking

import dev.chandra.scroll_less.detection.Targets
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class UsageTrackerTest {

    @Test
    fun `first observation yields no delta`() {
        val t = UsageTracker()
        assertNull(t.update(Targets.INSTAGRAM, false, 1000))
    }

    @Test
    fun `ticks attribute time to the active app and surface`() {
        val t = UsageTracker()
        t.update(Targets.INSTAGRAM, false, 1000)
        val d1 = t.tick(2000)!!
        assertEquals(Targets.INSTAGRAM, d1.pkg)
        assertEquals(1000, d1.foregroundMs)
        assertEquals(0, d1.surfaceMs)

        t.update(Targets.INSTAGRAM, true, 2000)
        val d2 = t.tick(3500)!!
        assertEquals(1500, d2.foregroundMs)
        assertEquals(1500, d2.surfaceMs)
    }

    @Test
    fun `switching apps bills the previous app`() {
        val t = UsageTracker()
        t.update(Targets.INSTAGRAM, true, 1000)
        val d = t.update(Targets.YOUTUBE, false, 4000)!!
        assertEquals(Targets.INSTAGRAM, d.pkg)
        assertEquals(3000, d.foregroundMs)
        assertEquals(3000, d.surfaceMs)
        assertEquals(Targets.YOUTUBE, t.activePackage)
    }

    @Test
    fun `leaving stops the clock`() {
        val t = UsageTracker()
        t.update(Targets.YOUTUBE, true, 1000)
        val d = t.leave(2500)!!
        assertEquals(1500, d.surfaceMs)
        assertNull(t.activePackage)
        assertNull(t.tick(9000))
    }

    @Test
    fun `gaps longer than maxGap are discarded`() {
        val t = UsageTracker(maxGapMs = 5000)
        t.update(Targets.INSTAGRAM, true, 1000)
        assertNull("device was asleep; must not bill 60 s", t.tick(61_000))
        assertEquals(1000, t.tick(62_000)!!.foregroundMs)
    }
}
