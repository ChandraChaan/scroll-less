import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/models.dart';
import '../data/preferences.dart';
import '../data/stats_repository.dart';
import '../native/scrollless_platform.dart';

/// Single source of truth for the UI: live state from the service, permission
/// status, overlay preference and the SQLite history. Screens listen to it.
class AppController extends ChangeNotifier with WidgetsBindingObserver {
  AppController({
    required this.platform,
    required this.repository,
    required this.preferences,
  });

  final ScrollLessPlatform platform;
  final StatsRepository repository;
  final AppPreferences preferences;

  LiveState live = LiveState.initial();
  bool? accessibilityEnabled;
  bool overlayEnabled = true;
  bool disclosureAccepted = false;
  int dailyGoal = 0;
  bool widgetAdded = false;
  bool pinWidgetSupported = false;
  List<DaySummary> last30 = const [];
  List<ReelEvent> recentEvents = const [];
  Object? error;
  bool _started = false;
  StreamSubscription<LiveState>? _sub;

  List<DaySummary> get last7 => last30.length <= 7 ? last30 : last30.sublist(last30.length - 7);

  DaySummary? get yesterday => last30.length >= 2 ? last30[last30.length - 2] : null;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _sub = platform.liveState.listen(
      (s) {
        live = s;
        notifyListeners();
      },
      onError: (Object e) {
        error = e;
        notifyListeners();
      },
    );
    await refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    try {
      final results = await Future.wait<Object?>([
        platform.isAccessibilityEnabled(),
        platform.getOverlayEnabled(),
        repository.history(days: 30),
        repository.recentEvents(limit: 30),
        platform.getTodayStats(),
        preferences.disclosureAccepted,
        platform.getDailyGoal(),
        platform.isWidgetAdded(),
        platform.isPinWidgetSupported(),
      ]);
      accessibilityEnabled = results[0] as bool;
      overlayEnabled = results[1] as bool;
      last30 = summarizeByDay(results[2] as List<DailyStat>, days: 30);
      recentEvents = results[3] as List<ReelEvent>;
      disclosureAccepted = results[5] as bool;
      dailyGoal = results[6] as int;
      widgetAdded = results[7] as bool;
      pinWidgetSupported = results[8] as bool;
      final todayRows = results[4] as List<DailyStat>;
      if (todayRows.isNotEmpty) {
        live = LiveState(
          day: live.day,
          serviceRunning: live.serviceRunning,
          activePackage: live.activePackage,
          onSurface: live.onSurface,
          stats: todayRows,
        );
      }
      error = null;
    } catch (e) {
      error = e;
    }
    notifyListeners();
  }

  Future<void> setOverlayEnabled(bool value) async {
    overlayEnabled = value;
    notifyListeners();
    await platform.setOverlayEnabled(value);
  }

  Future<void> acceptDisclosure() async {
    disclosureAccepted = true;
    notifyListeners();
    await preferences.setDisclosureAccepted(true);
  }

  Future<void> openAccessibilitySettings() => platform.openAccessibilitySettings();

  Future<void> setDailyGoal(int goal) async {
    dailyGoal = goal;
    notifyListeners();
    await platform.setDailyGoal(goal);
  }

  /// Returns true when the launcher showed its pin sheet.
  Future<bool> requestPinWidget() async {
    final shown = await platform.requestPinWidget();
    // The sheet is asynchronous; poll a few times so the status updates once the user taps "Add".
    for (var i = 0; i < 6 && !widgetAdded; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      widgetAdded = await platform.isWidgetAdded();
      notifyListeners();
    }
    return shown;
  }

  /// True when every recommended setup step is done.
  bool get setupComplete => accessibilityEnabled == true && widgetAdded;

  Future<void> resetToday() async {
    await platform.resetToday();
    await refresh();
  }

  Future<void> clearAllData() async {
    await platform.clearAllData();
    await refresh();
  }
}
