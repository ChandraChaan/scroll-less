import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/stats_repository.dart';
import '../native/scrollless_platform.dart';
import 'widgets.dart';

/// Dashboard: setup state, today's counts per app, 7-day history, recent
/// detections and settings.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.platform, required this.repository});

  final ScrollLessPlatform platform;
  final StatsRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  LiveState _live = LiveState.initial();
  bool? _accessibilityEnabled;
  bool _overlayEnabled = true;
  List<DaySummary> _week = const [];
  List<ReelEvent> _events = const [];
  StreamSubscription<LiveState>? _sub;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = widget.platform.liveState.listen(
      (s) {
        if (!mounted) return;
        setState(() => _live = s);
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = e);
      },
    );
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait<Object?>([
        widget.platform.isAccessibilityEnabled(),
        widget.platform.getOverlayEnabled(),
        widget.repository.history(days: 7),
        widget.repository.recentEvents(limit: 20),
        widget.platform.getTodayStats(),
      ]);
      if (!mounted) return;
      final todayRows = results[4] as List<DailyStat>;
      setState(() {
        _accessibilityEnabled = results[0] as bool;
        _overlayEnabled = results[1] as bool;
        _week = summarizeByDay(results[2] as List<DailyStat>);
        _events = results[3] as List<ReelEvent>;
        _live = LiveState(
          day: _live.day,
          serviceRunning: _live.serviceRunning,
          activePackage: _live.activePackage,
          onSurface: _live.onSurface,
          stats: todayRows.isEmpty ? _live.stats : todayRows,
        );
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _toggleOverlay(bool v) async {
    setState(() => _overlayEnabled = v);
    await widget.platform.setOverlayEnabled(v);
  }

  Future<void> _confirm(String title, String body, Future<void> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
        ],
      ),
    );
    if (ok == true) {
      await action();
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _live.total;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ScrollLess'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (_error != null)
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Could not load data: $_error', style: TextStyle(color: scheme.onErrorContainer)),
                ),
              ),
            if (_accessibilityEnabled == false)
              SetupCard(onEnable: widget.platform.openAccessibilitySettings),
            if (_accessibilityEnabled == true && _live.activeApp != null)
              LiveBanner(app: _live.activeApp!, onSurface: _live.onSurface),
            const SizedBox(height: 8),
            TodayHero(total: total),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: AppStatCard(app: TrackedApp.instagram, stat: _live.statFor(TrackedApp.instagram))),
                const SizedBox(width: 12),
                Expanded(child: AppStatCard(app: TrackedApp.youtube, stat: _live.statFor(TrackedApp.youtube))),
              ],
            ),
            const SizedBox(height: 20),
            SectionTitle('Last 7 days'),
            WeekChart(days: _week),
            const SizedBox(height: 20),
            SectionTitle('Recent detections'),
            RecentEventsList(events: _events),
            const SizedBox(height: 20),
            SectionTitle('Settings'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Floating counter'),
                    subtitle: const Text('Show today\'s count and time over Instagram and YouTube'),
                    value: _overlayEnabled,
                    onChanged: _toggleOverlay,
                  ),
                  ListTile(
                    leading: const Icon(Icons.accessibility_new),
                    title: const Text('Accessibility service'),
                    subtitle: Text(
                      _accessibilityEnabled == null
                          ? 'Checking…'
                          : _accessibilityEnabled!
                              ? 'Enabled'
                              : 'Disabled — tap to enable',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.platform.openAccessibilitySettings,
                  ),
                  ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: const Text('Reset today'),
                    onTap: () => _confirm(
                      'Reset today?',
                      'Today\'s counts and times will be deleted. Other days are kept.',
                      widget.platform.resetToday,
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_forever, color: scheme.error),
                    title: Text('Delete all data', style: TextStyle(color: scheme.error)),
                    onTap: () => _confirm(
                      'Delete all data?',
                      'Every count, time and detection stored on this device will be removed.',
                      widget.platform.clearAllData,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionTitle('Privacy & diagnostics'),
            const PrivacyCard(),
            Card(
              child: ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Send a test crash'),
                subtitle: const Text('Forces a crash so Crashlytics reporting can be verified. The app will close.'),
                onTap: () => _confirm(
                  'Crash the app?',
                  'ScrollLess will crash on purpose and report it to Firebase Crashlytics on the next launch.',
                  widget.platform.testCrash,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
