package dev.chandra.scroll_less.detection

import java.security.MessageDigest

/**
 * Identity of the video currently on screen, derived from the words visible in
 * its page (creator handle, caption, audio title). Two fingerprints are
 * compared with the overlap coefficient |A∩B| / min(|A|,|B|), which stays high
 * when a caption is merely expanded ("...more") but drops when the creator or
 * caption changes.
 *
 * Only a salted-free SHA-1 of the token set is ever persisted; the raw words
 * never leave memory.
 */
class Fingerprint(rawTokens: Collection<String>) {
    val tokens: Set<String> = rawTokens.toSortedSet()
    val isEmpty: Boolean get() = tokens.isEmpty()
    val size: Int get() = tokens.size

    /** Overlap coefficient in [0, 1]; 0 when either side is empty. */
    fun similarity(other: Fingerprint): Double {
        if (isEmpty || other.isEmpty) return 0.0
        val small = if (size <= other.size) tokens else other.tokens
        val large = if (size <= other.size) other.tokens else tokens
        var common = 0
        for (t in small) if (t in large) common++
        return common.toDouble() / small.size.toDouble()
    }

    /** Stable hash used for storage/dedup logs; never contains the words themselves. */
    val key: String by lazy {
        val md = MessageDigest.getInstance("SHA-1")
        val bytes = md.digest(tokens.joinToString("\u0001").toByteArray(Charsets.UTF_8))
        bytes.joinToString("") { "%02x".format(it) }.substring(0, 16)
    }

    override fun toString(): String = "Fingerprint(${tokens.size} tokens, $key)"
}

/**
 * Turns the text visible inside a page node into a [Fingerprint].
 *
 * Volatile strings (counters, timestamps, progress) and generic UI chrome
 * (Like, Share, Follow, Subscribe...) are stripped so that the fingerprint only
 * changes when the *content* changes.
 */
object FingerprintBuilder {
    private val NUMERIC = Regex("""^[\d.,:/KMBkmb%+\s]+$""")
    private val SPLIT = Regex("""[\s•·|•,!?()\[\]{}"“”]+""")
    private val STOP_WORDS = setOf(
        // Generic chrome shared by both apps
        "like", "likes", "liked", "comment", "comments", "share", "shares", "send", "save", "saved",
        "follow", "following", "subscribe", "subscribed", "remix", "more", "less", "mute", "unmute",
        "play", "pause", "dislike", "report", "sound", "sounds", "audio", "original", "music",
        "video", "videos", "views", "view", "reel", "reels", "short", "shorts", "home", "search",
        "profile", "create", "notifications", "inbox", "messages", "camera", "back", "close",
        "sponsored", "suggested", "for", "you", "and", "the", "with", "this", "that", "from",
        "ago", "hours", "hour", "minutes", "minute", "days", "day", "weeks", "week", "seconds",
        "double", "tap", "button", "image", "photo", "see", "translation", "verified", "menu",
        "options", "description", "channel", "watch", "again", "next", "previous", "loading",
        "progress", "bar", "seek", "slider", "volume", "captions", "subtitles", "settings",
    )

    fun build(page: UiNode, maxTokens: Int = 48): Fingerprint {
        val tokens = LinkedHashSet<String>()
        page.walk { node ->
            if (tokens.size >= maxTokens) return@walk
            addTokens(node.text, tokens, maxTokens)
            addTokens(node.contentDescription, tokens, maxTokens)
        }
        return Fingerprint(tokens)
    }

    private fun addTokens(raw: CharSequence?, out: MutableSet<String>, max: Int) {
        if (raw.isNullOrBlank()) return
        val s = raw.toString().trim()
        if (s.length < 2 || NUMERIC.matches(s)) return
        for (word in SPLIT.split(s.lowercase())) {
            if (out.size >= max) return
            val w = word.trim('#', '.', '\'', '’', ':', ';', '-', '_', '*')
            if (w.length < 3) continue
            if (w in STOP_WORDS) continue
            if (NUMERIC.matches(w)) continue
            out.add(w)
        }
    }
}
