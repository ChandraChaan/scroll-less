import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_less/src/app/app_controller.dart';
import 'package:scroll_less/src/data/models.dart';
import 'package:scroll_less/src/data/preferences.dart';
import 'package:scroll_less/src/data/stats_repository.dart';
import 'package:scroll_less/src/native/scrollless_platform.dart';
import 'package:scroll_less/src/theme/app_theme.dart';
import 'package:scroll_less/src/ui/app_shell.dart';
import 'package:scroll_less/src/ui/home_screen.dart';
import 'package:scroll_less/src/ui/onboarding_screen.dart';
import 'package:scroll_less/src/ui/settings_screen.dart';

class FakePlatform implements ScrollLessPlatform {
  FakePlatform({this.accessibilityEnabled = true});

  bool accessibilityEnabled;
  bool overlayEnabled = true;
  int openSettingsCalls = 0;
  int resetCalls = 0;
  int clearCalls = 0;
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
  Future<void> clearAllData() async => clearCalls++;
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

AppController makeController({bool accessibilityEnabled = true, FakePlatform? platform, FakeRepository? repo, AppPreferences? prefs}) =>
    AppController(
      platform: platform ?? FakePlatform(accessibilityEnabled: accessibilityEnabled),
      repository: repo ?? FakeRepository(),
      preferences: prefs ?? InMemoryAppPreferences(),
    );

Widget wrap(Widget child) => MaterialApp(theme: buildTheme(Brightness.light), home: child);

void main() {
  group('Onboarding', () {
    testWidgets('walks through three steps, then shows the disclosure and opens settings on agree', (tester) async {
      final platform = FakePlatform();
      final prefs = InMemoryAppPreferences();
      final c = makeController(platform: platform, prefs: prefs);
      var done = false;
      await tester.pumpWidget(wrap(OnboardingScreen(controller: c, onDone: () => done = true)));
      await tester.pumpAndSettle();

      expect(find.text('Know how much you scroll'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(find.text('Time, per app'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(find.text('Private by design'), findsOneWidget);
      expect(find.text('Enable ScrollLess'), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(find.text('ScrollLess needs the Accessibility service'), findsOneWidget);
      expect(platform.openSettingsCalls, 0);

      await tester.tap(find.text('Agree & continue'));
      await tester.pumpAndSettle();
      expect(platform.openSettingsCalls, 1);
      expect(await prefs.onboardingDone, isTrue);
      expect(await prefs.disclosureAccepted, isTrue);
      expect(done, isTrue);
    });

    testWidgets('declining the disclosure does not open settings', (tester) async {
      final platform = FakePlatform();
      final prefs = InMemoryAppPreferences();
      final c = makeController(platform: platform, prefs: prefs);
      await tester.pumpWidget(wrap(OnboardingScreen(controller: c, onDone: () {})));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(platform.openSettingsCalls, 0);
      expect(await prefs.disclosureAccepted, isFalse);
    });
  });

  group('Home', () {
    testWidgets('shows setup card when the service is off and routes through the disclosure', (tester) async {
      final platform = FakePlatform(accessibilityEnabled: false);
      final c = makeController(platform: platform);
      await c.start();
      await tester.pumpWidget(wrap(HomeScreen(controller: c)));
      await tester.pumpAndSettle();

      expect(find.text('Counting is paused'), findsOneWidget);
      await tester.tap(find.byKey(const Key('enable-service')));
      await tester.pumpAndSettle();
      expect(find.text('ScrollLess needs the Accessibility service'), findsOneWidget);
      await tester.tap(find.text('Agree & continue'));
      await tester.pumpAndSettle();
      expect(platform.openSettingsCalls, 1);

      // Second time: disclosure already accepted, go straight to settings.
      await tester.tap(find.byKey(const Key('enable-service')));
      await tester.pumpAndSettle();
      expect(find.text('ScrollLess needs the Accessibility service'), findsNothing);
      expect(platform.openSettingsCalls, 2);
    });

    testWidgets('renders live counts and the live banner', (tester) async {
      final platform = FakePlatform();
      final c = makeController(platform: platform);
      await c.start();
      await tester.pumpWidget(wrap(HomeScreen(controller: c)));
      await tester.pumpAndSettle();
      expect(find.text('Counting is paused'), findsNothing);

      final day = dayKey(DateTime.now());
      platform.controller.add(LiveState(
        day: day,
        serviceRunning: true,
        activePackage: TrackedApp.instagram.packageName,
        onSurface: true,
        stats: [
          DailyStat(day: day, packageName: TrackedApp.instagram.packageName, reels: 12, surfaceMs: 125000, foregroundMs: 300000),
          DailyStat(day: day, packageName: TrackedApp.youtube.packageName, reels: 5, surfaceMs: 60000, foregroundMs: 90000),
        ],
      ));
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byKey(const Key('today-total-count'))).data, '17');
      expect(tester.widget<Text>(find.byKey(const Key('count-instagram'))).data, '12');
      expect(tester.widget<Text>(find.byKey(const Key('count-youtube'))).data, '5');
      expect(find.text('Instagram is open'), findsOneWidget);
      expect(find.text('Watching Reels · counting live'), findsOneWidget);
    });
  });

  group('Settings', () {
    testWidgets('overlay switch and reset confirmation reach the platform', (tester) async {
      final platform = FakePlatform();
      final c = makeController(platform: platform);
      await c.start();
      await tester.pumpWidget(wrap(SettingsScreen(controller: c, appVersion: '1.1.0 (4)')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(platform.overlayEnabled, isFalse);

      await tester.tap(find.text('Reset today'));
      await tester.pumpAndSettle();
      expect(find.text('Reset today?'), findsOneWidget);
      expect(platform.resetCalls, 0);
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(platform.resetCalls, 1);
      expect(find.text('1.1.0 (4)'), findsOneWidget);
    });
  });

  group('Shell', () {
    testWidgets('bottom navigation switches tabs', (tester) async {
      final c = makeController();
      await c.start();
      await tester.pumpWidget(wrap(AppShell(controller: c, appVersion: '1.1.0')));
      await tester.pumpAndSettle();
      expect(find.text('ScrollLess'), findsOneWidget);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('7 days'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Floating counter'), findsOneWidget);
    });
  });
}
