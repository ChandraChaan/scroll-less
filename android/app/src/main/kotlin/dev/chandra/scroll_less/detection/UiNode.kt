package dev.chandra.scroll_less.detection

/**
 * Minimal, framework-independent view of an accessibility node.
 *
 * The real implementation wraps [android.view.accessibility.AccessibilityNodeInfo];
 * tests build trees of [FakeUiNode]s. Keeping detection logic on this interface
 * means every heuristic in this package can be unit tested on the JVM.
 */
interface UiNode {
    /** Fully qualified view id, e.g. `com.instagram.android:id/clips_viewer_view_pager`. */
    val viewId: String?
    val className: String?
    val text: String?
    val contentDescription: String?
    val isScrollable: Boolean
    val bounds: Box

    /** Row/position of this node inside its parent collection (RecyclerView/ViewPager), if reported. */
    val collectionItemIndex: Int?
    val children: List<UiNode>
}

/** Screen-space rectangle in pixels. */
data class Box(val left: Int, val top: Int, val right: Int, val bottom: Int) {
    val width: Int get() = (right - left).coerceAtLeast(0)
    val height: Int get() = (bottom - top).coerceAtLeast(0)
    val area: Long get() = width.toLong() * height.toLong()
    fun contains(x: Int, y: Int): Boolean = x in left until right && y in top until bottom

    companion object {
        val EMPTY = Box(0, 0, 0, 0)
    }
}

/** Depth-first traversal with a hard cap on visited nodes so huge trees stay cheap. */
inline fun UiNode.walk(maxNodes: Int = 2500, visit: (UiNode) -> Unit) {
    val stack = ArrayDeque<UiNode>()
    stack.addLast(this)
    var visited = 0
    while (stack.isNotEmpty() && visited < maxNodes) {
        val node = stack.removeLast()
        visited++
        visit(node)
        val kids = node.children
        for (i in kids.indices.reversed()) stack.addLast(kids[i])
    }
}

/** Simple in-memory node used by unit tests. */
data class FakeUiNode(
    override val viewId: String? = null,
    override val className: String? = null,
    override val text: String? = null,
    override val contentDescription: String? = null,
    override val isScrollable: Boolean = false,
    override val bounds: Box = Box.EMPTY,
    override val collectionItemIndex: Int? = null,
    override val children: List<UiNode> = emptyList(),
) : UiNode
