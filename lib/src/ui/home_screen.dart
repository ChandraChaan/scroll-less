import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../data/models.dart';
import 'accessibility_disclosure.dart';
import 'widgets.dart';

/// "Today" tab.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final live = c.live;
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: const Text('ScrollLess'),
            actions: [
              IconButton(tooltip: 'Refresh', onPressed: c.refresh, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: c.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                if (c.error != null)
                  Card(
                    color: scheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Could not load data: ${c.error}', style: TextStyle(color: scheme.onErrorContainer)),
                    ),
                  ),
                if (c.accessibilityEnabled == false) ...[
                  SetupCard(onEnable: () => showAccessibilityDisclosure(context, c)),
                  const SizedBox(height: 14),
                ],
                if (c.accessibilityEnabled == true && live.activeApp != null) ...[
                  LiveBanner(app: live.activeApp!, onSurface: live.onSurface),
                  const SizedBox(height: 14),
                ],
                TodayHero(total: live.total, yesterday: c.yesterday),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: AppStatCard(app: TrackedApp.instagram, stat: live.statFor(TrackedApp.instagram))),
                    const SizedBox(width: 12),
                    Expanded(child: AppStatCard(app: TrackedApp.youtube, stat: live.statFor(TrackedApp.youtube))),
                  ],
                ),
                const SizedBox(height: 24),
                SectionTitle('This week'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.last7.fold<int>(0, (a, d) => a + d.reels)} videos · '
                          '${formatDuration(c.last7.fold<Duration>(Duration.zero, (a, d) => a + d.surfaceTime))} scrolling',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        DayBarChart(days: c.last7),
                        const SizedBox(height: 8),
                        const ChartLegend(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SectionTitle('Recent detections'),
                RecentEventsList(events: c.recentEvents),
              ],
            ),
          ),
        );
      },
    );
  }
}
