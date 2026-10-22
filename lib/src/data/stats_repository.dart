import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Read side of the local SQLite store.
///
/// The accessibility service (Kotlin) writes `scrollless.db`; this repository
/// opens the same file with `sqflite` for history queries. The schema below
/// mirrors `StatsDatabase.kt` and is created idempotently so either side can
/// open the file first.
abstract class StatsRepository {
  Future<List<DailyStat>> history({int days = 7});
  Future<List<ReelEvent>> recentEvents({int limit = 20});
  Future<List<DailyStat>> today();
}

class SqliteStatsRepository implements StatsRepository {
  SqliteStatsRepository({DatabaseFactory? factory, String? path})
      : _factory = factory ?? databaseFactory,
        _path = path; // ignore: prefer_initializing_formals

  static const databaseName = 'scrollless.db';

  final DatabaseFactory _factory;
  final String? _path;
  Database? _db;

  Future<Database> get _database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    final path = _path ?? p.join(await _factory.getDatabasesPath(), databaseName);
    final db = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          try {
            await db.rawQuery('PRAGMA journal_mode = WAL');
          } catch (_) {}
        },
        onOpen: ensureSchema,
      ),
    );
    _db = db;
    return db;
  }

  /// Creates the tables if the native side has not done so yet.
  static Future<void> ensureSchema(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS daily_stats (
        day TEXT NOT NULL,
        package TEXT NOT NULL,
        reels INTEGER NOT NULL DEFAULT 0,
        surface_ms INTEGER NOT NULL DEFAULT 0,
        foreground_ms INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (day, package)
      )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS reel_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts INTEGER NOT NULL,
        day TEXT NOT NULL,
        package TEXT NOT NULL,
        fingerprint TEXT NOT NULL,
        confidence TEXT NOT NULL
      )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_reel_events_day ON reel_events(day)');
  }

  @override
  Future<List<DailyStat>> today() async {
    final db = await _database;
    final rows = await db.query('daily_stats', where: 'day = ?', whereArgs: [dayKey(DateTime.now())]);
    return rows.map(DailyStat.fromMap).toList(growable: false);
  }

  @override
  Future<List<DailyStat>> history({int days = 7}) async {
    final db = await _database;
    final from = dayKey(DateTime.now().subtract(Duration(days: days - 1)));
    final rows = await db.query('daily_stats', where: 'day >= ?', whereArgs: [from], orderBy: 'day ASC');
    return rows.map(DailyStat.fromMap).toList(growable: false);
  }

  @override
  Future<List<ReelEvent>> recentEvents({int limit = 20}) async {
    final db = await _database;
    final rows = await db.query('reel_events', orderBy: 'ts DESC', limit: limit);
    return rows.map(ReelEvent.fromMap).toList(growable: false);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

/// Groups raw rows into one entry per day for the last [days] days, oldest first.
List<DaySummary> summarizeByDay(List<DailyStat> rows, {int days = 7, DateTime? now}) {
  final today = now ?? DateTime.now();
  final out = <DaySummary>[];
  for (var i = days - 1; i >= 0; i--) {
    final d = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
    final key = dayKey(d);
    final perApp = <TrackedApp, DailyStat>{};
    for (final r in rows.where((r) => r.day == key)) {
      final app = r.app;
      if (app != null) perApp[app] = r;
    }
    out.add(DaySummary(date: d, perApp: perApp));
  }
  return out;
}

class DaySummary {
  const DaySummary({required this.date, required this.perApp});

  final DateTime date;
  final Map<TrackedApp, DailyStat> perApp;

  int get reels => perApp.values.fold(0, (a, s) => a + s.reels);
  Duration get surfaceTime => Duration(milliseconds: perApp.values.fold(0, (a, s) => a + s.surfaceMs));
  int reelsFor(TrackedApp app) => perApp[app]?.reels ?? 0;
}
