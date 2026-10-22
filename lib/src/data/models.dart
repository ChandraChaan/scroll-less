/// Data types shared by the native bridge, the SQLite repository and the UI.
library;

/// Apps whose short-form video surfaces ScrollLess tracks.
enum TrackedApp {
  instagram('com.instagram.android', 'Instagram', 'Reels'),
  youtube('com.google.android.youtube', 'YouTube', 'Shorts');

  const TrackedApp(this.packageName, this.label, this.unitLabel);

  final String packageName;
  final String label;

  /// What one counted video is called in this app.
  final String unitLabel;

  static TrackedApp? fromPackage(String? pkg) {
    for (final a in TrackedApp.values) {
      if (a.packageName == pkg) return a;
    }
    return null;
  }
}

/// Per-day, per-app statistics (one row of the `daily_stats` table).
class DailyStat {
  const DailyStat({
    required this.day,
    required this.packageName,
    required this.reels,
    required this.surfaceMs,
    required this.foregroundMs,
  });

  factory DailyStat.fromMap(Map<dynamic, dynamic> m) => DailyStat(
        day: m['day'] as String,
        packageName: (m['package'] ?? m['packageName']) as String,
        reels: (m['reels'] as num?)?.toInt() ?? 0,
        surfaceMs: ((m['surfaceMs'] ?? m['surface_ms'] ?? 0) as num).toInt(),
        foregroundMs: ((m['foregroundMs'] ?? m['foreground_ms'] ?? 0) as num).toInt(),
      );

  /// `yyyy-MM-dd` in local time.
  final String day;
  final String packageName;

  /// Videos counted.
  final int reels;

  /// Time spent with the Reels/Shorts viewer on screen.
  final int surfaceMs;

  /// Time the app was in the foreground at all.
  final int foregroundMs;

  TrackedApp? get app => TrackedApp.fromPackage(packageName);
  Duration get surfaceTime => Duration(milliseconds: surfaceMs);
  Duration get foregroundTime => Duration(milliseconds: foregroundMs);

  DailyStat operator +(DailyStat other) => DailyStat(
        day: day,
        packageName: packageName == other.packageName ? packageName : 'total',
        reels: reels + other.reels,
        surfaceMs: surfaceMs + other.surfaceMs,
        foregroundMs: foregroundMs + other.foregroundMs,
      );

  static DailyStat empty(String day, String packageName) =>
      DailyStat(day: day, packageName: packageName, reels: 0, surfaceMs: 0, foregroundMs: 0);
}

/// One counted video (one row of `reel_events`). Only a hash of the on-screen
/// words is stored, never the words themselves.
class ReelEvent {
  const ReelEvent({
    required this.id,
    required this.timestamp,
    required this.day,
    required this.packageName,
    required this.fingerprint,
    required this.confidence,
  });

  factory ReelEvent.fromMap(Map<dynamic, dynamic> m) => ReelEvent(
        id: (m['id'] as num).toInt(),
        timestamp: DateTime.fromMillisecondsSinceEpoch((m['ts'] as num).toInt()),
        day: m['day'] as String,
        packageName: m['package'] as String,
        fingerprint: m['fingerprint'] as String,
        confidence: m['confidence'] as String,
      );

  final int id;
  final DateTime timestamp;
  final String day;
  final String packageName;
  final String fingerprint;
  final String confidence;

  TrackedApp? get app => TrackedApp.fromPackage(packageName);
}

/// Live snapshot pushed by the accessibility service.
class LiveState {
  const LiveState({
    required this.day,
    required this.serviceRunning,
    required this.activePackage,
    required this.onSurface,
    required this.stats,
  });

  factory LiveState.fromMap(Map<dynamic, dynamic> m) => LiveState(
        day: m['day'] as String,
        serviceRunning: m['serviceRunning'] as bool? ?? false,
        activePackage: m['activePackage'] as String?,
        onSurface: m['onSurface'] as bool? ?? false,
        stats: ((m['stats'] as List?) ?? const [])
            .map((e) => DailyStat.fromMap(e as Map))
            .toList(growable: false),
      );

  static LiveState initial() => LiveState(
        day: dayKey(DateTime.now()),
        serviceRunning: false,
        activePackage: null,
        onSurface: false,
        stats: const [],
      );

  final String day;
  final bool serviceRunning;
  final String? activePackage;
  final bool onSurface;
  final List<DailyStat> stats;

  TrackedApp? get activeApp => TrackedApp.fromPackage(activePackage);

  DailyStat statFor(TrackedApp app) => stats.firstWhere(
        (s) => s.packageName == app.packageName,
        orElse: () => DailyStat.empty(day, app.packageName),
      );

  DailyStat get total => stats.fold(
        DailyStat.empty(day, 'total'),
        (acc, s) => acc + s,
      );
}

/// Formats a date as the `yyyy-MM-dd` key used by the database.
String dayKey(DateTime d) {
  String two(int v) => v < 10 ? '0$v' : '$v';
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// Human-friendly duration: `1h 05m`, `12m`, `45s`.
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  if (m > 0) return '${m}m';
  return '${s}s';
}
