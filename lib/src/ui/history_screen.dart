import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../data/models.dart';
import 'widgets.dart';

/// "History" tab: 7 or 30 day chart plus a per-day breakdown.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _range = 7;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final days = _range == 7 ? c.last7 : c.last30;
        final theme = Theme.of(context);
        final total = days.fold<int>(0, (a, d) => a + d.reels);
        final time = days.fold<Duration>(Duration.zero, (a, d) => a + d.surfaceTime);
        final activeDays = days.where((d) => d.reels > 0).length;
        final avg = activeDays == 0 ? 0 : (total / activeDays).round();
        final withData = days.where((d) => d.reels > 0 || d.surfaceTime > Duration.zero).toList().reversed.toList();

        return Scaffold(
          appBar: AppBar(title: const Text('History')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 7, label: Text('7 days')),
                  ButtonSegment(value: 30, label: Text('30 days')),
                ],
                selected: {_range},
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Stat(label: 'videos', value: '$total'),
                  const SizedBox(width: 10),
                  _Stat(label: 'scrolling', value: formatDuration(time)),
                  const SizedBox(width: 10),
                  _Stat(label: 'avg / active day', value: '$avg'),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DayBarChart(days: days),
                      const SizedBox(height: 8),
                      const ChartLegend(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SectionTitle('Day by day'),
              if (withData.isEmpty)
                const EmptyCard(icon: Icons.calendar_today_outlined, text: 'No activity recorded in this period.')
              else
                Card(
                  child: Column(
                    children: [
                      for (final d in withData)
                        ListTile(
                          title: Text(_label(d.date), style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            [for (final app in TrackedApp.values) if (d.reelsFor(app) > 0) '${d.reelsFor(app)} ${app.unitLabel}'].join(' · '),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${d.reels}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                              Text(formatDuration(d.surfaceTime), style: theme.textTheme.labelSmall),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _label(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
