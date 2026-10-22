import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_less/src/data/models.dart';
import 'package:scroll_less/src/data/stats_repository.dart';
import 'package:scroll_less/src/native/scrollless_platform.dart';
import 'package:scroll_less/src/ui/home_screen.dart';

class FakePlatform implements ScrollLessPlatform {
  FakePlatform({this.accessibilityEnabled = true});

  bool accessibilityEnabled;
  bool overlayEnabled = true;
  int openSettingsCalls = 0;
  int resetCalls = 0;
  final controller = StreamController<LiveState>.broadcast();
  List<DailyStat> todayStats = const [];

  @override
  Future<bool> isAccessibilityEnabled() async => accessibilityEnabled;
  @override
  Future<bool> isServiceRunning() async => accessibilityEnabled;
  @override
  Future<void> openAccessibilitySettings() async => openSettingsCalls++;
  @override
  Future<bool> getOverlayEnabled() async => overlayEnabled;
  @override
  Future<void> setOverlayEnabled(bool enabled) async => overlayEnabled = enabled;
  @override
  Future<List<DailyStat>> getTodayStats() async => todayStats;
  @override
  Future<List<DailyStat>> getHistory(int days) async => const [];
  @override
  Future<List<ReelEvent>> getRecentEvents(int limit) async => const [];
  @override
  Future<void> resetToday() async => resetCalls++;
  @override
  Future<void> clearAllData() async {}
  @override
  Future<void> testCrash() async {}
  @override
  Stream<LiveState> get liveState => controller.stream;
}

class FakeRepository implements StatsRepository {
  List<DailyStat> rows = const [];
  List<ReelEvent> events = const [];
  @override
  Future<List<DailyStat>> history({int days = 7}) async => rows;
  @override
  Future<List<ReelEvent>> recentEvents({int limit = 20}) async => events;
  @override
  Future<List<DailyStat>> today() async => rows;
}

Widget wrap(ScrollLessPlatform platform, StatsRepository repo) =>
    MaterialApp(home: HomeScreen(platform: platform, repository: repo));

void main() {
  testWidgets('shows setup card when accessibility is disabled and opens settings', (tester) async {
    final platform = FakePlatform(accessibilityEnabled: false);
    await tester.pumpWidget(wrap(platform, FakeRepository()));
    await tester.pumpAndSettle();

    expect(find.text('One step to start'), findsOneWidget);
    await tester.tap(find.text('Open accessibility settings'));
    await tester.pump();
    expect(platform.openSettingsCalls, 1);
  });

  testWidgets('hides setup card when enabled and renders live counts', (tester) async {
    final platform = FakePlatform(accessibilityEnabled: true);
    await tester.pumpWidget(wrap(platform, FakeRepository()));
    await tester.pumpAndSettle();
    expect(find.text('One step to start'), findsNothing);

    platform.controller.add(LiveState(
      day: dayKey(DateTime.now()),
      serviceRunning: true,
      activePackage: TrackedApp.instagram.packageName,
      onSurface: true,
      stats: [
        DailyStat(day: dayKey(DateTime.now()), packageName: TrackedApp.instagram.packageName, reels: 12, surfaceMs: 125000, foregroundMs: 300000),
        DailyStat(day: dayKey(DateTime.now()), packageName: TrackedApp.youtube.packageName, reels: 5, surfaceMs: 60000, foregroundMs: 90000),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today-total-count')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('today-total-count'))).data, '17');
    expect(tester.widget<Text>(find.byKey(const Key('count-instagram'))).data, '12');
    expect(tester.widget<Text>(find.byKey(const Key('count-youtube'))).data, '5');
    expect(find.text('Instagram is open'), findsOneWidget);
    expect(find.text('Watching Reels — counting live'), findsOneWidget);
  });

  testWidgets('overlay switch calls the platform', (tester) async {
    final platform = FakePlatform();
    await tester.pumpWidget(wrap(platform, FakeRepository()));
    await tester.pumpAndSettle();

    final switchFinder = find.byType(SwitchListTile);
    await tester.scrollUntilVisible(switchFinder, 200);
    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(platform.overlayEnabled, isFalse);
  });

  testWidgets('reset today asks for confirmation first', (tester) async {
    final platform = FakePlatform();
    await tester.pumpWidget(wrap(platform, FakeRepository()));
    await tester.pumpAndSettle();

    final tile = find.text('Reset today');
    await tester.scrollUntilVisible(tile, 200);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('Reset today?'), findsOneWidget);
    expect(platform.resetCalls, 0);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(platform.resetCalls, 1);
  });
}
