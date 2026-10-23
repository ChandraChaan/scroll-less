import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stats_repository.dart';
import '../theme/app_theme.dart';
import 'feed_animation.dart';

Color appColor(TrackedApp app) => switch (app) {
      TrackedApp.instagram => Brand.instagram,
      TrackedApp.youtube => Brand.youtube,
    };

IconData appIcon(TrackedApp app) => switch (app) {
      TrackedApp.instagram => Icons.camera_alt_outlined,
      TrackedApp.youtube => Icons.play_circle_outline,
    };

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            ?trailing,
          ],
        ),
      );
}

/// Gradient card shown until the accessibility service is enabled.
class SetupCard extends StatelessWidget {
  const SetupCard({super.key, required this.onEnable});
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(gradient: Brand.gradient, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.accessibility_new_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Counting is paused',
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Turn on the ScrollLess accessibility service so Reels and Shorts can be counted. It only looks at the Instagram and YouTube screens.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('enable-service'),
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Brand.indigoDeep, minimumSize: const Size.fromHeight(46)),
            onPressed: onEnable,
            icon: const Icon(Icons.settings_rounded),
            label: const Text('Turn on in Settings'),
          ),
        ],
      ),
    );
  }
}

/// Small nudge shown while the home-screen widget is not added.
class WidgetNudge extends StatelessWidget {
  const WidgetNudge({super.key, required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Brand.coral.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.widgets_rounded, color: Brand.coral),
        ),
        title: Text('Add the home-screen widget', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: const Text('Today\'s count and goal at a glance'),
        trailing: FilledButton(
          key: const Key('nudge-add-widget'),
          onPressed: onAdd,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
          child: const Text('Add'),
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
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Icon(appIcon(app), color: appColor(app), size: 28),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: onSurface ? Brand.mint : theme.colorScheme.outline, shape: BoxShape.circle),
            ),
          ],
        ),
        title: Text('${app.label} is open', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(onSurface ? 'Watching ${app.unitLabel} · counting live' : 'Not on ${app.unitLabel} right now'),
      ),
    );
  }
}

/// Big "today" card: animated count, looping feed illustration inside the
/// goal ring, time stats and comparison with yesterday.
class TodayHero extends StatelessWidget {
  const TodayHero({super.key, required this.total, this.yesterday, this.goal = 0});
  final DailyStat total;
  final DaySummary? yesterday;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = yesterday == null ? null : total.reels - yesterday!.reels;
    final progress = goal > 0 ? total.reels / goal : 0.0;
    return Container(
      decoration: BoxDecoration(
        gradient: Brand.gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Brand.indigo.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('TODAY', style: theme.textTheme.labelMedium?.copyWith(color: Colors.white70, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
              const Spacer(),
              ?delta == null ? null : _DeltaChip(delta: delta),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedCount(
                      key: const Key('today-total-count'),
                      value: total.reels,
                      style: theme.textTheme.displayLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1, letterSpacing: -2),
                    ),
                    const SizedBox(height: 6),
                    Text('short videos', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                    if (goal > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        total.reels > goal ? '${total.reels - goal} over your goal of $goal' : '${goal - total.reels} left of your $goal goal',
                        style: theme.textTheme.bodySmall?.copyWith(color: total.reels > goal ? const Color(0xFFFFB4B4) : Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              GoalRing(
                progress: goal > 0 ? progress : 0,
                size: 104,
                track: goal > 0 ? Colors.white24 : Colors.transparent,
                child: const FeedAnimation(size: 72),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroStat(icon: Icons.timer_outlined, value: formatDuration(total.surfaceTime), label: 'scrolling'),
              const SizedBox(width: 12),
              _HeroStat(icon: Icons.phone_android_rounded, value: formatDuration(total.foregroundTime), label: 'in the apps'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta});
  final int delta;

  @override
  Widget build(BuildContext context) {
    final up = delta > 0;
    final text = delta == 0 ? 'same as yesterday' : '${up ? '+' : ''}$delta vs yesterday';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(delta == 0 ? Icons.remove : (up ? Icons.north_east : Icons.south_west), size: 14, color: up ? Brand.coral : Brand.mint),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70)),
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
    final color = appColor(app);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(appIcon(app), color: color, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(app.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 14),
            Text('${stat.reels}', key: Key('count-${app.name}'), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1)),
            const SizedBox(height: 2),
            Text(app.unitLabel, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            _row(theme, Icons.timer_outlined, '${formatDuration(stat.surfaceTime)} on ${app.unitLabel}'),
            _row(theme, Icons.phone_android_outlined, '${formatDuration(stat.foregroundTime)} in app'),
          ],
        ),
      ),
    );
  }

  Widget _row(ThemeData theme, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Expanded(child: Text(text, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
          ],
        ),
      );
}

/// Stacked bars of videos per day, one segment per app.
class DayBarChart extends StatelessWidget {
  const DayBarChart({super.key, required this.days, this.showWeekday = true});
  final List<DaySummary> days;
  final bool showWeekday;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final max = days.fold<int>(0, (m, d) => d.reels > m ? d.reels : m);
    final compact = days.length > 10;

    return SizedBox(
      height: 150,
      child: days.isEmpty
          ? const Center(child: Text('No data yet'))
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in days)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: compact ? 1.5 : 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (d.reels > 0 && !compact) Text('${d.reels}', style: theme.textTheme.labelSmall),
                          const SizedBox(height: 2),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: max == 0 ? 0.03 : (d.reels / max).clamp(0.03, 1.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(compact ? 3 : 7),
                                  child: Column(
                                    children: [
                                      for (final app in TrackedApp.values)
                                        if (d.reelsFor(app) > 0)
                                          Expanded(flex: d.reelsFor(app), child: Container(color: appColor(app))),
                                      if (d.reels == 0) Expanded(child: Container(color: scheme.surfaceContainerHighest)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (showWeekday && !compact)
                            Text(_weekdays[d.date.weekday - 1], style: theme.textTheme.labelSmall)
                          else if (showWeekday && d.date.day == 1 || (showWeekday && compact && days.indexOf(d) % 7 == 0))
                            Text('${d.date.day}', style: theme.textTheme.labelSmall)
                          else
                            const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final app in TrackedApp.values) ...[
          Container(width: 10, height: 10, decoration: BoxDecoration(color: appColor(app), borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          Text(app.label, style: theme.textTheme.labelSmall),
          const SizedBox(width: 14),
        ],
      ],
    );
  }
}

class RecentEventsList extends StatelessWidget {
  const RecentEventsList({super.key, required this.events, this.limit = 8});
  final List<ReelEvent> events;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (events.isEmpty) {
      return const EmptyCard(
        icon: Icons.movie_outlined,
        text: 'Nothing counted yet. Open Instagram Reels or YouTube Shorts and start scrolling.',
      );
    }
    return Card(
      child: Column(
        children: [
          for (final e in events.take(limit))
            ListTile(
              dense: true,
              leading: Icon(e.app == null ? Icons.movie_outlined : appIcon(e.app!), color: e.app == null ? null : appColor(e.app!)),
              title: Text('${e.app?.label ?? e.packageName} ${_singular(e.app)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_time(e.timestamp)),
              trailing: Tooltip(
                message: e.confidence == 'HIGH' ? 'Detected via a known Reels/Shorts view id' : 'Detected via layout heuristics',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (e.confidence == 'HIGH' ? Brand.mint : Brand.amber).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(e.confidence.toLowerCase(), style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _singular(TrackedApp? app) => switch (app) {
        TrackedApp.instagram => 'Reel',
        TrackedApp.youtube => 'Short',
        null => 'video',
      };

  static String _time(DateTime t) {
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    String two(int v) => v.toString().padLeft(2, '0');
    final hm = '${two(t.hour)}:${two(t.minute)}';
    return sameDay ? 'Today $hm' : '${dayKey(t)} $hm';
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          ],
        ),
      ),
    );
  }
}
