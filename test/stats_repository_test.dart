import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:scroll_less/src/data/models.dart';
import 'package:scroll_less/src/data/stats_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Exercises the real SQLite schema (via sqflite_common_ffi on the host) using
/// the same SQL the Kotlin service runs, so both sides stay compatible.
void main() {
  late Directory dir;
  late SqliteStatsRepository repo;
  late Database raw;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('scrollless_test');
    final path = p.join(dir.path, 'scrollless.db');
    repo = SqliteStatsRepository(factory: databaseFactoryFfi, path: path);
    raw = await databaseFactoryFfi.openDatabase(path);
    await SqliteStatsRepository.ensureSchema(raw);
  });

  tearDown(() async {
    await repo.close();
    await raw.close();
    await dir.delete(recursive: true);
  });

  /// Mirrors StatsDatabase.recordReel in Kotlin.
  Future<void> nativeRecordReel(String day, String pkg, int ts) async {
    await raw.transaction((txn) async {
      await txn.rawInsert('INSERT OR IGNORE INTO daily_stats(day, package) VALUES(?, ?)', [day, pkg]);
      await txn.rawUpdate('UPDATE daily_stats SET reels = reels + 1 WHERE day = ? AND package = ?', [day, pkg]);
      await txn.insert('reel_events', {'ts': ts, 'day': day, 'package': pkg, 'fingerprint': 'abc123', 'confidence': 'HIGH'});
    });
  }

  Future<void> nativeAddUsage(String day, String pkg, int fg, int surface) async {
    await raw.rawInsert('INSERT OR IGNORE INTO daily_stats(day, package) VALUES(?, ?)', [day, pkg]);
    await raw.rawUpdate(
      'UPDATE daily_stats SET foreground_ms = foreground_ms + ?, surface_ms = surface_ms + ? WHERE day = ? AND package = ?',
      [fg, surface, day, pkg],
    );
  }

  test('today() reads rows written with the native SQL', () async {
    final today = dayKey(DateTime.now());
    await nativeRecordReel(today, TrackedApp.instagram.packageName, 1);
    await nativeRecordReel(today, TrackedApp.instagram.packageName, 2);
    await nativeAddUsage(today, TrackedApp.instagram.packageName, 5000, 3000);
    await nativeRecordReel(today, TrackedApp.youtube.packageName, 3);

    final rows = await repo.today();
    final ig = rows.singleWhere((r) => r.app == TrackedApp.instagram);
    final yt = rows.singleWhere((r) => r.app == TrackedApp.youtube);
    expect(ig.reels, 2);
    expect(ig.foregroundMs, 5000);
    expect(ig.surfaceMs, 3000);
    expect(yt.reels, 1);
  });

  test('history() returns only the requested window, oldest first', () async {
    final now = DateTime.now();
    for (var i = 0; i < 10; i++) {
      final day = dayKey(now.subtract(Duration(days: i)));
      await nativeAddUsage(day, TrackedApp.youtube.packageName, 1000 * (i + 1), 0);
    }
    final rows = await repo.history(days: 7);
    expect(rows.length, 7);
    expect(rows.first.day, dayKey(now.subtract(const Duration(days: 6))));
    expect(rows.last.day, dayKey(now));
  });

  test('recentEvents() is newest first and respects limit', () async {
    final today = dayKey(DateTime.now());
    for (var i = 1; i <= 5; i++) {
      await nativeRecordReel(today, TrackedApp.youtube.packageName, i * 1000);
    }
    final events = await repo.recentEvents(limit: 3);
    expect(events.length, 3);
    expect(events.first.timestamp.millisecondsSinceEpoch, 5000);
    expect(events.last.timestamp.millisecondsSinceEpoch, 3000);
    expect(events.first.confidence, 'HIGH');
    expect(events.first.fingerprint, 'abc123');
  });
}
