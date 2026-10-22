package dev.chandra.scroll_less.data

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.time.LocalDate

/** One row of per-day, per-app statistics. */
data class DailyStat(
    val day: String,
    val pkg: String,
    val reels: Int,
    val surfaceMs: Long,
    val foregroundMs: Long,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "day" to day,
        "package" to pkg,
        "reels" to reels,
        "surfaceMs" to surfaceMs,
        "foregroundMs" to foregroundMs,
    )
}

data class ReelEvent(
    val id: Long,
    val ts: Long,
    val day: String,
    val pkg: String,
    val fingerprint: String,
    val confidence: String,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "ts" to ts,
        "day" to day,
        "package" to pkg,
        "fingerprint" to fingerprint,
        "confidence" to confidence,
    )
}

/**
 * Local-only SQLite store. Nothing here ever leaves the device.
 *
 * The same file is opened read-only by the Flutter side through `sqflite`
 * (both live in one process, so SQLite's locking keeps them consistent).
 */
class StatsDatabase private constructor(context: Context) :
    SQLiteOpenHelper(context.applicationContext, NAME, null, VERSION) {

    override fun onConfigure(db: SQLiteDatabase) {
        db.enableWriteAheadLogging()
    }

    override fun onCreate(db: SQLiteDatabase) {
        createSchema(db)
    }

    override fun onOpen(db: SQLiteDatabase) {
        // Idempotent: the Flutter side may have created an older/partial schema first.
        createSchema(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        createSchema(db)
    }

    private fun createSchema(db: SQLiteDatabase) {
        db.execSQL(
            """CREATE TABLE IF NOT EXISTS daily_stats (
                day TEXT NOT NULL,
                package TEXT NOT NULL,
                reels INTEGER NOT NULL DEFAULT 0,
                surface_ms INTEGER NOT NULL DEFAULT 0,
                foreground_ms INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (day, package)
            )""",
        )
        db.execSQL(
            """CREATE TABLE IF NOT EXISTS reel_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts INTEGER NOT NULL,
                day TEXT NOT NULL,
                package TEXT NOT NULL,
                fingerprint TEXT NOT NULL,
                confidence TEXT NOT NULL
            )""",
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_reel_events_day ON reel_events(day)")
    }

    private fun ensureRow(db: SQLiteDatabase, day: String, pkg: String) {
        val cv = ContentValues().apply {
            put("day", day)
            put("package", pkg)
        }
        db.insertWithOnConflict("daily_stats", null, cv, SQLiteDatabase.CONFLICT_IGNORE)
    }

    @Synchronized
    fun recordReel(day: String, pkg: String, ts: Long, fingerprintKey: String, confidence: String) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            ensureRow(db, day, pkg)
            db.execSQL("UPDATE daily_stats SET reels = reels + 1 WHERE day = ? AND package = ?", arrayOf(day, pkg))
            val cv = ContentValues().apply {
                put("ts", ts)
                put("day", day)
                put("package", pkg)
                put("fingerprint", fingerprintKey)
                put("confidence", confidence)
            }
            db.insert("reel_events", null, cv)
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    @Synchronized
    fun addUsage(day: String, pkg: String, foregroundMs: Long, surfaceMs: Long) {
        if (foregroundMs <= 0 && surfaceMs <= 0) return
        val db = writableDatabase
        db.beginTransaction()
        try {
            ensureRow(db, day, pkg)
            db.execSQL(
                "UPDATE daily_stats SET foreground_ms = foreground_ms + ?, surface_ms = surface_ms + ? WHERE day = ? AND package = ?",
                arrayOf<Any>(foregroundMs, surfaceMs, day, pkg),
            )
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun statsForDay(day: String): List<DailyStat> {
        val out = ArrayList<DailyStat>()
        readableDatabase.rawQuery(
            "SELECT day, package, reels, surface_ms, foreground_ms FROM daily_stats WHERE day = ?",
            arrayOf(day),
        ).use { c ->
            while (c.moveToNext()) out.add(DailyStat(c.getString(0), c.getString(1), c.getInt(2), c.getLong(3), c.getLong(4)))
        }
        return out
    }

    fun history(days: Int): List<DailyStat> {
        val from = LocalDate.now().minusDays((days - 1).coerceAtLeast(0).toLong()).toString()
        val out = ArrayList<DailyStat>()
        readableDatabase.rawQuery(
            "SELECT day, package, reels, surface_ms, foreground_ms FROM daily_stats WHERE day >= ? ORDER BY day ASC",
            arrayOf(from),
        ).use { c ->
            while (c.moveToNext()) out.add(DailyStat(c.getString(0), c.getString(1), c.getInt(2), c.getLong(3), c.getLong(4)))
        }
        return out
    }

    fun recentEvents(limit: Int): List<ReelEvent> {
        val out = ArrayList<ReelEvent>()
        readableDatabase.rawQuery(
            "SELECT id, ts, day, package, fingerprint, confidence FROM reel_events ORDER BY ts DESC LIMIT ?",
            arrayOf(limit.toString()),
        ).use { c ->
            while (c.moveToNext()) out.add(ReelEvent(c.getLong(0), c.getLong(1), c.getString(2), c.getString(3), c.getString(4), c.getString(5)))
        }
        return out
    }

    @Synchronized
    fun resetDay(day: String) {
        val db = writableDatabase
        db.delete("daily_stats", "day = ?", arrayOf(day))
        db.delete("reel_events", "day = ?", arrayOf(day))
    }

    @Synchronized
    fun clearAll() {
        val db = writableDatabase
        db.delete("daily_stats", null, null)
        db.delete("reel_events", null, null)
    }

    companion object {
        const val NAME = "scrollless.db"
        const val VERSION = 1

        @Volatile private var instance: StatsDatabase? = null

        fun get(context: Context): StatsDatabase =
            instance ?: synchronized(this) { instance ?: StatsDatabase(context).also { instance = it } }

        fun today(): String = LocalDate.now().toString()
    }
}
