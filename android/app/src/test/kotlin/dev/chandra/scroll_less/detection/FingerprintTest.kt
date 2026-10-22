package dev.chandra.scroll_less.detection

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FingerprintTest {

    private fun page(vararg texts: String) = FakeUiNode(
        children = texts.map { FakeUiNode(text = it) },
    )

    @Test
    fun `strips counters, timestamps and ui chrome`() {
        val fp = FingerprintBuilder.build(
            page("12.3K", "1,204", "0:12 / 0:30", "Like", "Share", "Follow", "2d", "travel_with_maya", "Sunrise over Hampi"),
        )
        assertEquals(setOf("travel_with_maya", "sunrise", "over", "hampi"), fp.tokens)
    }

    @Test
    fun `caption expansion keeps high similarity`() {
        val collapsed = FingerprintBuilder.build(page("@maya", "Sunrise over Hampi... more"))
        val expanded = FingerprintBuilder.build(page("@maya", "Sunrise over Hampi, the best boulders in India #travel #hampi #sunrise"))
        assertTrue(collapsed.similarity(expanded) >= 0.9)
    }

    @Test
    fun `different creators and captions are dissimilar`() {
        val a = FingerprintBuilder.build(page("@maya", "Sunrise over Hampi", "Original audio"))
        val b = FingerprintBuilder.build(page("@rohit_fit", "Leg day finisher you must try", "Original audio"))
        assertTrue(a.similarity(b) < 0.3)
    }

    @Test
    fun `empty page gives empty fingerprint and zero similarity`() {
        val empty = FingerprintBuilder.build(page("Like", "123"))
        assertTrue(empty.isEmpty)
        assertEquals(0.0, empty.similarity(FingerprintBuilder.build(page("hello world"))), 0.0)
    }

    @Test
    fun `key is stable and does not contain raw words`() {
        val a = Fingerprint(listOf("hampi", "sunrise"))
        val b = Fingerprint(listOf("sunrise", "hampi"))
        assertEquals(a.key, b.key)
        assertFalse(a.key.contains("hampi"))
        assertEquals(16, a.key.length)
    }
}
