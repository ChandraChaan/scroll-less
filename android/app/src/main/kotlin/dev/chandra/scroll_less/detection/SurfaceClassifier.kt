package dev.chandra.scroll_less.detection

/** Packages whose short-form video surfaces we track. */
object Targets {
    const val INSTAGRAM = "com.instagram.android"
    const val YOUTUBE = "com.google.android.youtube"
    val ALL: Set<String> = setOf(INSTAGRAM, YOUTUBE)

    fun label(pkg: String): String = when (pkg) {
        INSTAGRAM -> "Instagram"
        YOUTUBE -> "YouTube"
        else -> pkg
    }

    fun unitLabel(pkg: String): String = when (pkg) {
        INSTAGRAM -> "Reels"
        YOUTUBE -> "Shorts"
        else -> "videos"
    }
}

enum class Confidence { HIGH, MEDIUM, NONE }

/**
 * Result of looking at one window: are we on a Reels/Shorts surface, which node
 * is the vertical pager, and which child of it is the video currently in view.
 */
data class SurfaceResult(
    val onSurface: Boolean,
    val pager: UiNode?,
    val currentPage: UiNode?,
    val confidence: Confidence,
) {
    companion object {
        val OFF = SurfaceResult(false, null, null, Confidence.NONE)
    }
}

/**
 * Decides whether the current Instagram / YouTube window is the full-screen
 * Reels / Shorts viewer and locates the page under the screen centre.
 *
 * Strategy, in order of trust:
 *  1. Known resource ids (`clips_viewer_*` for Instagram, `reel_recycler` for
 *     YouTube Shorts — YouTube still calls Shorts "reels" internally).
 *  2. Heuristic: a scrollable pager that fills almost the whole screen, whose
 *     subtree carries surface markers (`clips_` / `reel_` ids), and whose
 *     centred child is at least 60% of the screen height.
 *
 * Both apps change ids between releases, so the heuristic path keeps the app
 * working (with MEDIUM confidence) when ids drift.
 */
class SurfaceClassifier(private val screenWidth: Int, private val screenHeight: Int) {

    private data class Rules(val pagerIds: List<String>, val markerIds: List<String>)

    private val rules = mapOf(
        Targets.INSTAGRAM to Rules(
            pagerIds = listOf("clips_viewer_view_pager", "clips_viewer_recycler", "clips_viewer_pager", "clips_view_pager"),
            markerIds = listOf("clips_video_container", "clips_viewer", "clips_media", "clips_caption", "clips_author", "clips_audio"),
        ),
        Targets.YOUTUBE to Rules(
            pagerIds = listOf("reel_recycler", "reel_pager", "shorts_recycler", "reel_vertical_pager"),
            markerIds = listOf("reel_player_page", "reel_player_overlay", "reel_watch_player", "reel_video_interactions", "reel_player_footer", "shorts_player"),
        ),
    )

    /** View classes that behave like a vertical pager. Plain ScrollViews are excluded on purpose. */
    private val pagerClassHints = listOf("RecyclerView", "ViewPager", "Pager", "ListView")

    fun classify(root: UiNode, pkg: String): SurfaceResult {
        val r = rules[pkg] ?: return SurfaceResult.OFF
        var knownPager: UiNode? = null
        val scrollables = ArrayList<UiNode>()

        root.walk { node ->
            val id = shortId(node)
            if (id != null && knownPager == null && r.pagerIds.any { id == it || id.contains(it) }) knownPager = node
            if (node.isScrollable && isTall(node) && isPagerClass(node)) scrollables.add(node)
        }

        knownPager?.let { pager ->
            val page = centredChild(pager)
            if (page != null || isTall(pager)) {
                return SurfaceResult(true, pager, page ?: pager, Confidence.HIGH)
            }
        }

        // Heuristic path: the *innermost* tall pager-like scrollable whose centred child is
        // near full screen and whose own subtree carries Reels/Shorts markers. Markers
        // elsewhere in the window (e.g. YouTube's `reel_time_bar` on the Home tab) do not count.
        val candidate = scrollables
            .sortedBy { it.bounds.area }
            .firstOrNull { pager ->
                val page = centredChild(pager) ?: return@firstOrNull false
                page.bounds.height >= screenHeight * 0.6 &&
                    page.bounds.width >= screenWidth * 0.8 &&
                    hasMarker(pager, r.markerIds)
            } ?: return SurfaceResult.OFF

        return SurfaceResult(true, candidate, centredChild(candidate), Confidence.MEDIUM)
    }

    private fun shortId(node: UiNode): String? {
        val raw = node.viewId ?: return null
        val id = raw.substringAfter("/", raw)
        return id.ifEmpty { null }
    }

    private fun isPagerClass(node: UiNode): Boolean {
        val cls = node.className ?: return false
        return pagerClassHints.any { cls.contains(it) }
    }

    private fun hasMarker(subtree: UiNode, markers: List<String>): Boolean {
        var found = false
        subtree.walk(maxNodes = 800) { n ->
            if (!found) {
                val id = shortId(n)
                if (id != null && markers.any { id.contains(it) }) found = true
            }
        }
        return found
    }

    private fun isTall(node: UiNode): Boolean =
        node.bounds.height >= screenHeight * 0.6 && node.bounds.width >= screenWidth * 0.8

    /** The direct child of [pager] that covers the screen centre (largest wins on ties). */
    private fun centredChild(pager: UiNode): UiNode? {
        val cx = screenWidth / 2
        val cy = screenHeight / 2
        return pager.children
            .filter { it.bounds.contains(cx, cy) }
            .maxByOrNull { it.bounds.area }
    }
}
