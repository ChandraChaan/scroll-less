package dev.chandra.scroll_less.data

import android.os.Handler
import android.os.Looper
import java.util.concurrent.CopyOnWriteArraySet

/**
 * In-process pub/sub between the accessibility service and the Flutter
 * EventChannel. Both run in the same process, so no IPC is needed.
 */
object StatsBus {
    fun interface Listener {
        fun onUpdate(payload: Map<String, Any?>)
    }

    private val listeners = CopyOnWriteArraySet<Listener>()
    private val main = Handler(Looper.getMainLooper())

    @Volatile var last: Map<String, Any?>? = null
        private set

    fun subscribe(l: Listener) {
        listeners.add(l)
        last?.let { l.onUpdate(it) }
    }

    fun unsubscribe(l: Listener) {
        listeners.remove(l)
    }

    fun publish(payload: Map<String, Any?>) {
        last = payload
        main.post { for (l in listeners) l.onUpdate(payload) }
    }
}
