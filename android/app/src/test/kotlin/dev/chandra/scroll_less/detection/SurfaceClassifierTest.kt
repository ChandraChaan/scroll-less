package dev.chandra.scroll_less.detection

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

class SurfaceClassifierTest {
    private val w = 1080
    private val h = 2400
    private val classifier = SurfaceClassifier(w, h)
    private val full = Box(0, 0, w, h)

    private fun pageAt(offsetY: Int, index: Int?, vararg texts: String) = FakeUiNode(
        className = "android.widget.FrameLayout",
        bounds = Box(0, offsetY, w, offsetY + h),
        collectionItemIndex = index,
        children = texts.map { FakeUiNode(text = it) },
    )

    @Test
    fun `instagram clips viewer is detected by id with high confidence`() {
        val pager = FakeUiNode(
            viewId = "com.instagram.android:id/clips_viewer_view_pager",
            className = "androidx.viewpager.widget.ViewPager",
            isScrollable = true,
            bounds = full,
            children = listOf(pageAt(-h, 0, "prev"), pageAt(0, 1, "maya", "Sunrise over Hampi"), pageAt(h, 2, "next")),
        )
        val root = FakeUiNode(bounds = full, children = listOf(FakeUiNode(viewId = "com.instagram.android:id/action_bar"), pager))
        val r = classifier.classify(root, Targets.INSTAGRAM)
        assertTrue(r.onSurface)
        assertEquals(Confidence.HIGH, r.confidence)
        assertSame(pager, r.pager)
        assertEquals(1, r.currentPage?.collectionItemIndex)
    }

    @Test
    fun `youtube shorts reel_recycler is detected`() {
        val pager = FakeUiNode(
            viewId = "com.google.android.youtube:id/reel_recycler",
            className = "androidx.recyclerview.widget.RecyclerView",
            isScrollable = true,
            bounds = full,
            children = listOf(pageAt(0, 7, "Leg day finisher", "@rohit_fit")),
        )
        val r = classifier.classify(FakeUiNode(bounds = full, children = listOf(pager)), Targets.YOUTUBE)
        assertTrue(r.onSurface)
        assertEquals(Confidence.HIGH, r.confidence)
        assertEquals(7, r.currentPage?.collectionItemIndex)
    }

    @Test
    fun `instagram home feed is not a surface`() {
        val feed = FakeUiNode(
            viewId = "com.instagram.android:id/feed_recycler",
            className = "androidx.recyclerview.widget.RecyclerView",
            isScrollable = true,
            bounds = full,
            children = listOf(
                FakeUiNode(bounds = Box(0, 0, w, 900), children = listOf(FakeUiNode(text = "post one"))),
                FakeUiNode(bounds = Box(0, 900, w, 1800), children = listOf(FakeUiNode(text = "post two"))),
            ),
        )
        val r = classifier.classify(FakeUiNode(bounds = full, children = listOf(feed)), Targets.INSTAGRAM)
        assertFalse(r.onSurface)
    }

    @Test
    fun `unknown ids fall back to heuristic with medium confidence when markers exist`() {
        val pager = FakeUiNode(
            viewId = "com.instagram.android:id/some_new_pager_name",
            className = "androidx.recyclerview.widget.RecyclerView",
            isScrollable = true,
            bounds = full,
            children = listOf(
                FakeUiNode(
                    bounds = Box(0, 0, w, h),
                    children = listOf(
                        FakeUiNode(viewId = "com.instagram.android:id/clips_video_container"),
                        FakeUiNode(text = "maya"),
                    ),
                ),
            ),
        )
        val r = classifier.classify(FakeUiNode(bounds = full, children = listOf(pager)), Targets.INSTAGRAM)
        assertTrue(r.onSurface)
        assertEquals(Confidence.MEDIUM, r.confidence)
        assertNotNull(r.currentPage)
    }

    @Test
    fun `heuristic needs a near full-screen centred child`() {
        val pager = FakeUiNode(
            viewId = "com.google.android.youtube:id/results",
            className = "androidx.recyclerview.widget.RecyclerView",
            isScrollable = true,
            bounds = full,
            children = listOf(
                FakeUiNode(bounds = Box(0, 1000, w, 1400), children = listOf(FakeUiNode(viewId = "com.google.android.youtube:id/reel_item_thumbnail"))),
            ),
        )
        val r = classifier.classify(FakeUiNode(bounds = full, children = listOf(pager)), Targets.YOUTUBE)
        assertFalse("Shorts shelf inside the home feed must not count as the Shorts player", r.onSurface)
    }

    @Test
    fun `youtube home tab with reel_time_bar outside a full-screen ScrollView is not a surface`() {
        // Reproduces the real tree captured from YouTube 21.41 on the Home tab.
        val results = FakeUiNode(
            viewId = "com.google.android.youtube:id/results",
            className = "android.support.v7.widget.RecyclerView",
            isScrollable = true,
            bounds = Box(0, 262, w, 2337),
            children = listOf(
                FakeUiNode(bounds = Box(0, 262, w, 1100), children = listOf(FakeUiNode(text = "Sponsored - Amazon Music"))),
                FakeUiNode(bounds = Box(0, 1100, w, 1900), children = listOf(FakeUiNode(text = "Shorts"), FakeUiNode(text = "Road accident"))),
            ),
        )
        val coordinator = FakeUiNode(
            viewId = "com.google.android.youtube:id/watch_while_layout_coordinator_layout",
            className = "android.widget.ScrollView",
            isScrollable = true,
            bounds = Box(0, 136, w, 2337),
            children = listOf(FakeUiNode(bounds = Box(0, 136, w, 2337), children = listOf(results))),
        )
        val root = FakeUiNode(
            bounds = full,
            children = listOf(
                coordinator,
                FakeUiNode(viewId = "com.google.android.youtube:id/reel_time_bar", bounds = full),
            ),
        )
        val r = classifier.classify(root, Targets.YOUTUBE)
        assertFalse(r.onSurface)
    }

    @Test
    fun `real youtube shorts tree is detected with high confidence`() {
        val page = FakeUiNode(
            viewId = "com.google.android.youtube:id/reel_player_page_container",
            bounds = Box(0, 136, w, 2211),
            collectionItemIndex = 3,
            children = listOf(
                FakeUiNode(viewId = "com.google.android.youtube:id/reel_video_interactions", contentDescription = "Go to channel @Evoindia"),
                FakeUiNode(text = "How fast can the new Mini Cooper S do a lap"),
            ),
        )
        val recycler = FakeUiNode(
            viewId = "com.google.android.youtube:id/reel_recycler",
            className = "android.support.v7.widget.RecyclerView",
            isScrollable = true,
            bounds = Box(0, 136, w, 2211),
            children = listOf(page),
        )
        val root = FakeUiNode(
            bounds = full,
            children = listOf(
                FakeUiNode(
                    viewId = "com.google.android.youtube:id/watch_while_layout_coordinator_layout",
                    className = "android.widget.ScrollView",
                    isScrollable = true,
                    bounds = full,
                    children = listOf(FakeUiNode(viewId = "com.google.android.youtube:id/reel_watch_fragment_root", bounds = Box(0, 136, w, 2211), children = listOf(recycler))),
                ),
                FakeUiNode(viewId = "com.google.android.youtube:id/reel_time_bar", bounds = full),
            ),
        )
        val r = classifier.classify(root, Targets.YOUTUBE)
        assertTrue(r.onSurface)
        assertEquals(Confidence.HIGH, r.confidence)
        assertSame(page, r.currentPage)
    }

    @Test
    fun `untracked package is never a surface`() {
        val r = classifier.classify(FakeUiNode(bounds = full), "com.example.other")
        assertFalse(r.onSurface)
    }
}
