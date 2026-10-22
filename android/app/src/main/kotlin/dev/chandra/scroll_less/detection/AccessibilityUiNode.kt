package dev.chandra.scroll_less.detection

import android.graphics.Rect
import android.view.accessibility.AccessibilityNodeInfo

/** [UiNode] backed by a live [AccessibilityNodeInfo]. Children are resolved lazily. */
class AccessibilityUiNode(private val info: AccessibilityNodeInfo) : UiNode {
    override val viewId: String? get() = info.viewIdResourceName
    override val className: String? get() = info.className?.toString()
    override val text: String? get() = info.text?.toString()
    override val contentDescription: String? get() = info.contentDescription?.toString()
    override val isScrollable: Boolean get() = info.isScrollable

    override val bounds: Box by lazy {
        val r = Rect()
        info.getBoundsInScreen(r)
        Box(r.left, r.top, r.right, r.bottom)
    }

    override val collectionItemIndex: Int?
        get() = info.collectionItemInfo?.let { ci -> if (ci.rowIndex >= 0) ci.rowIndex else null }

    override val children: List<UiNode> by lazy {
        val n = info.childCount
        if (n <= 0) emptyList() else buildList(n) {
            for (i in 0 until n) {
                val child = try { info.getChild(i) } catch (_: Exception) { null }
                if (child != null) add(AccessibilityUiNode(child))
            }
        }
    }
}
