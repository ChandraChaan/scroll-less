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
import 'package:scroll_less/src/ui/setup_screen.dart';

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
  int dailyGoal = 0;
  bool widgetAdded = false;
  int pinRequests = 0;
  @override
  Future<int> getDailyGoal() async => dailyGoal;
  @override
  Future<void> setDailyGoal(int goal) async => dailyGoal = goal;
  @override
  Future<bool> isWidgetAdded() async => widgetAdded;
  @override
  Future<bool> isPinWidgetSupported() async => true;
  @override
  Future<bool> requestPinWidget() async {
    pinRequests++;
    widgetAdded = true;
    return true;
  }
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

/// The hero's feed animation never settles, so pump a fixed amount instead of pumpAndSettle.
Future<void> settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> reveal(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(f);
  await settle(tester, 3);
}

void main() {
  group('Onboarding', () {
    testWidgets('walks through three steps and opens the guided setup', (tester) async {
      final platform = FakePlatform(accessibilityEnabled: false);
      final prefs = InMemoryAppPreferences();
      final c = makeController(platform: platform, prefs: prefs);
      await c.start();
      var done = false;
      await tester.pumpWidget(wrap(OnboardingScreen(controller: c, onDone: () => done = true)));
      await tester.pump();

      expect(find.text('Know how much you scroll'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await settle(tester);
      expect(find.text('Time, per app'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await settle(tester);
      expect(find.text('Enable ScrollLess'), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding-next')));
      await settle(tester);
      expect(find.text('Set up ScrollLess'), findsOneWidget);
      expect(await prefs.onboardingDone, isTrue);

      // Step 1 goes through the disclosure before system settings.
      await tester.tap(find.text('Turn on'));
      await tester.pump();
      expect(find.text('ScrollLess needs the Accessibility service'), findsOneWidget);
      await tester.tap(find.text('Agree & continue'));
      await tester.pump();
      expect(platform.openSettingsCalls, 1);
      expect(await prefs.disclosureAccepted, isTrue);

      await reveal(tester, find.byKey(const Key('setup-done')));
      await tester.tap(find.byKey(const Key('setup-done')));
      await settle(tester);
      expect(done, isTrue);
    });

    testWidgets('declining the disclosure does not open settings', (tester) async {
      final platform = FakePlatform(accessibilityEnabled: false);
      final prefs = InMemoryAppPreferences();
      final c = makeController(platform: platform, prefs: prefs);
      await c.start();
      await tester.pumpWidget(wrap(SetupScreen(controller: c)));
      await tester.pump();
      await tester.tap(find.text('Turn on'));
      await tester.pump();
      await tester.tap(find.text('Not now'));
      await tester.pump();
      expect(platform.openSettingsCalls, 0);
      expect(await prefs.disclosureAccepted, isFalse);
    });
  });

  group('Setup', () {
    testWidgets('widget pin and goal steps update their status', (tester) async {
      final platform = FakePlatform(accessibilityEnabled: true);
      final c = makeController(platform: platform);
      await c.start();
      await tester.pumpWidget(wrap(SetupScreen(controller: c)));
      await tester.pump();
      expect(find.text('1 of 3 done'), findsOneWidget);

      await reveal(tester, find.text('Add widget'));
      await tester.tap(find.text('Add widget'));
      await tester.pump(const Duration(seconds: 3));
      expect(platform.pinRequests, 1);
      expect(c.widgetAdded, isTrue);
      await tester.pump(const Duration(seconds: 15));
      expect(find.text('Added to your home screen'), findsOneWidget);

      await reveal(tester, find.text('Set goal'));
      await tester.tap(find.text('Set goal'));
      await settle(tester, 5);
      expect(find.text('Daily goal'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await settle(tester, 5);
      expect(platform.dailyGoal, 30);
      expect(find.text('Goal: 30 videos a day'), findsOneWidget);
    });
  });

  group('Home', () {
    testWidgets('shows setup card when the service is off and opens the guided setup', (tester) async {
      final platform = FakePlatform(accessibilityEnabled: false);
      final c = makeController(platform: platform);
      await c.start();
      await tester.pumpWidget(wrap(HomeScreen(controller: c)));
      await tester.pump();

      expect(find.text('Counting is paused'), findsOneWidget);
      await tester.tap(find.byKey(const Key('enable-service')));
      await settle(tester);
      expect(find.text('Set up ScrollLess'), findsOneWidget);
    });

    testWidgets('shows the widget nudge only while the widget is missing', (tester) async {
      final platform = FakePlatform(accessibilityEnabled: true);
      final c = makeController(platform: platform);
      await c.start();
      await tester.pumpWidget(wrap(HomeScreen(controller: c)));
      await tester.pump();
      expect(find.byKey(const Key('nudge-add-widget')), findsOneWidget);
      platform.widgetAdded = true;
      await c.refresh();
      await tester.pump();
      expect(find.byKey(const Key('nudge-add-widget')), findsNothing);
    });

    testWidgets('renders live counts and the live banner', (tester) async {
      final platform = FakePlatform();
      final c = makeController(platform: platform);
      await c.start();
      await tester.pumpWidget(wrap(HomeScreen(controller: c)));
      await tester.pump();
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
      await tester.pump(const Duration(seconds: 1));

      final countFinder = find.descendant(of: find.byKey(const Key('today-total-count')), matching: find.byType(Text));
      expect(tester.widget<Text>(countFinder).data, '17');
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
      await tester.pumpWidget(wrap(SettingsScreen(controller: c, appVersion: '1.2.0 (5)')));
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
      await reveal(tester, find.text('1.2.0 (5)'));
      expect(find.text('1.2.0 (5)'), findsOneWidget);
    });
  });

  group('Shell', () {
    testWidgets('bottom navigation switches tabs', (tester) async {
      final c = makeController();
      await c.start();
      await tester.pumpWidget(wrap(AppShell(controller: c, appVersion: '1.2.0')));
      await tester.pump();
      expect(find.text('ScrollLess'), findsOneWidget);
      await tester.tap(find.text('History'));
      await settle(tester);
      expect(find.text('7 days'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await settle(tester);
      expect(find.text('Floating counter'), findsOneWidget);
    });
  });
}
