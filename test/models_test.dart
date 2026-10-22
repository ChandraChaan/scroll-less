import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_less/src/data/models.dart';
import 'package:scroll_less/src/data/stats_repository.dart';

void main() {
  group('formatDuration', () {
    test('seconds, minutes, hours', () {
      expect(formatDuration(const Duration(seconds: 45)), '45s');
      expect(formatDuration(const Duration(minutes: 12, seconds: 30)), '12m');
      expect(formatDuration(const Duration(hours: 1, minutes: 5)), '1h 05m');
      expect(formatDuration(Duration.zero), '0s');
    });
  });

  group('dayKey', () {
    test('zero pads month and day', () {
      expect(dayKey(DateTime(2026, 1, 9)), '2026-01-09');
      expect(dayKey(DateTime(2026, 10, 22)), '2026-10-22');
    });
  });

  group('DailyStat', () {
    test('parses both native and sqflite key styles', () {
      final a = DailyStat.fromMap({'day': '2026-10-22', 'package': 'com.instagram.android', 'reels': 3, 'surfaceMs': 1000, 'foregroundMs': 2000});
      final b = DailyStat.fromMap({'day': '2026-10-22', 'package': 'com.instagram.android', 'reels': 3, 'surface_ms': 1000, 'foreground_ms': 2000});
      expect(a.reels, 3);
      expect(a.surfaceMs, b.surfaceMs);
      expect(a.foregroundMs, b.foregroundMs);
      expect(a.app, TrackedApp.instagram);
    });

    test('adds up into a total', () {
      final ig = DailyStat(day: 'd', packageName: TrackedApp.instagram.packageName, reels: 2, surfaceMs: 10, foregroundMs: 20);
      final yt = DailyStat(day: 'd', packageName: TrackedApp.youtube.packageName, reels: 5, surfaceMs: 30, foregroundMs: 40);
      final total = ig + yt;
      expect(total.reels, 7);
      expect(total.surfaceMs, 40);
      expect(total.foregroundMs, 60);
      expect(total.packageName, 'total');
    });
  });

  group('LiveState', () {
    test('statFor returns empty for missing app', () {
      final s = LiveState.fromMap({
        'day': '2026-10-22',
        'serviceRunning': true,
        'activePackage': 'com.google.android.youtube',
        'onSurface': true,
        'stats': [
          {'day': '2026-10-22', 'package': 'com.google.android.youtube', 'reels': 4, 'surfaceMs': 5000, 'foregroundMs': 9000},
        ],
      });
      expect(s.activeApp, TrackedApp.youtube);
      expect(s.statFor(TrackedApp.youtube).reels, 4);
      expect(s.statFor(TrackedApp.instagram).reels, 0);
      expect(s.total.reels, 4);
    });
  });

  group('summarizeByDay', () {
    test('fills missing days and groups per app, oldest first', () {
      final now = DateTime(2026, 10, 22, 15);
      final rows = [
        DailyStat(day: '2026-10-22', packageName: TrackedApp.instagram.packageName, reels: 3, surfaceMs: 1, foregroundMs: 1),
        DailyStat(day: '2026-10-22', packageName: TrackedApp.youtube.packageName, reels: 2, surfaceMs: 1, foregroundMs: 1),
        DailyStat(day: '2026-10-20', packageName: TrackedApp.youtube.packageName, reels: 7, surfaceMs: 1, foregroundMs: 1),
      ];
      final days = summarizeByDay(rows, days: 7, now: now);
      expect(days.length, 7);
      expect(days.first.date, DateTime(2026, 10, 16));
      expect(days.last.date, DateTime(2026, 10, 22));
      expect(days.last.reels, 5);
      expect(days.last.reelsFor(TrackedApp.instagram), 3);
      expect(days[4].reels, 7);
      expect(days[0].reels, 0);
    });
  });
}
