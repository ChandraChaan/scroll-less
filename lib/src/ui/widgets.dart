import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stats_repository.dart';

Color appColor(TrackedApp app, ColorScheme scheme) => switch (app) {
      TrackedApp.instagram => const Color(0xFFE1306C),
      TrackedApp.youtube => const Color(0xFFFF0033),
    };

IconData appIcon(TrackedApp app) => switch (app) {
      TrackedApp.instagram => Icons.camera_alt_outlined,
      TrackedApp.youtube => Icons.play_circle_outline,
    };

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

/// Shown until the accessibility service is enabled.
class SetupCard extends StatelessWidget {
  const SetupCard({super.key, required this.onEnable});
  final Future<void> Function() onEnable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.accessibility_new, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text('One step to start', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onPrimaryContainer)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ScrollLess counts Reels and Shorts by watching the Instagram and YouTube screens through '
              'Android\'s accessibility service. Enable "ScrollLess" under Installed apps / Downloaded apps.',
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onEnable,
              icon: const Icon(Icons.settings),
              label: const Text('Open accessibility settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveBanner extends StatelessWidget {
  const LiveBanner({super.key, required this.app, required this.onSurface});
  final TrackedApp app;
  final bool onSurface;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(appIcon(app), color: appColor(app, scheme)),
        title: Text('${app.label} is open'),
        subtitle: Text(onSurface ? 'Watching ${app.unitLabel} — counting live' : 'Not on ${app.unitLabel} right now'),
      ),
    );
  }
}

class TodayHero extends StatelessWidget {
  const TodayHero({super.key, required this.total});
  final DailyStat total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    '${total.reels}',
                    key: const Key('today-total-count'),
                    style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text('short videos watched', style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(Icons.timer_outlined, color: theme.colorScheme.primary),
                const SizedBox(height: 4),
                Text(formatDuration(total.surfaceTime), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                Text('scrolling', style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AppStatCard extends StatelessWidget {
  const AppStatCard({super.key, required this.app, required this.stat});
  final TrackedApp app;
  final DailyStat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = appColor(app, theme.colorScheme);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(appIcon(app), color: color, size: 20),
                const SizedBox(width: 6),
                Text(app.label, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            Text('${stat.reels}', key: Key('count-${app.name}'), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            Text(app.unitLabel, style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            _row(theme, Icons.timer_outlined, '${formatDuration(stat.surfaceTime)} on ${app.unitLabel}'),
            _row(theme, Icons.phone_android, '${formatDuration(stat.foregroundTime)} in app'),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Expanded(child: Text(text, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
          ],
        ),
      );
}

/// Stacked bars of videos per day, one segment per app.
class WeekChart extends StatelessWidget {
  const WeekChart({super.key, required this.days});
  final List<DaySummary> days;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final max = days.fold<int>(0, (m, d) => d.reels > m ? d.reels : m);
    final total = days.fold<int>(0, (a, d) => a + d.reels);
    final totalTime = days.fold<Duration>(Duration.zero, (a, d) => a + d.surfaceTime);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$total videos · ${formatDuration(totalTime)} scrolling', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: days.isEmpty
                  ? const Center(child: Text('No data yet'))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final d in days)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (d.reels > 0)
                                    Text('${d.reels}', style: theme.textTheme.labelSmall),
                                  const SizedBox(height: 2),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: FractionallySizedBox(
                                        heightFactor: max == 0 ? 0.02 : (d.reels / max).clamp(0.02, 1.0),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Column(
                                            children: [
                                              for (final app in TrackedApp.values)
                                                if (d.reelsFor(app) > 0)
                                                  Expanded(
                                                    flex: d.reelsFor(app),
                                                    child: Container(color: appColor(app, scheme)),
                                                  ),
                                              if (d.reels == 0)
                                                Expanded(child: Container(color: scheme.surfaceContainerHighest)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(_weekdays[d.date.weekday - 1], style: theme.textTheme.labelSmall),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final app in TrackedApp.values) ...[
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: appColor(app, scheme), borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 4),
                  Text(app.label, style: theme.textTheme.labelSmall),
                  const SizedBox(width: 12),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RecentEventsList extends StatelessWidget {
  const RecentEventsList({super.key, required this.events});
  final List<ReelEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (events.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nothing counted yet. Open Instagram Reels or YouTube Shorts and start scrolling.'),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (final e in events.take(10))
            ListTile(
              dense: true,
              leading: Icon(
                e.app == null ? Icons.movie_outlined : appIcon(e.app!),
                color: e.app == null ? null : appColor(e.app!, theme.colorScheme),
              ),
              title: Text('${e.app?.label ?? e.packageName} ${e.app?.unitLabel.substring(0, e.app!.unitLabel.length - 1) ?? 'video'}'),
              subtitle: Text(_time(e.timestamp)),
              trailing: Tooltip(
                message: e.confidence == 'HIGH'
                    ? 'Detected via a known Reels/Shorts view id'
                    : 'Detected via layout heuristics',
                child: Chip(
                  label: Text(e.confidence.toLowerCase(), style: theme.textTheme.labelSmall),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _time(DateTime t) {
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    String two(int v) => v.toString().padLeft(2, '0');
    final hm = '${two(t.hour)}:${two(t.minute)}';
    return sameDay ? 'Today $hm' : '${dayKey(t)} $hm';
  }
}

class PrivacyCard extends StatelessWidget {
  const PrivacyCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Your data stays on this phone', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• Only the Instagram and YouTube screens are read; other apps are ignored.\n'
              '• Counts and times live in a local SQLite database. No account, no sync, no analytics.\n'
              '• Each detection stores a short hash of the on-screen words, never the words themselves.\n'
              '• Crash reports (stack traces only) go to Firebase Crashlytics so bugs can be fixed.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
