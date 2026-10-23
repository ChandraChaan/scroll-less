import 'dart:async';

import 'package:flutter/services.dart';

import '../data/models.dart';

/// Bridge to the Kotlin side. Abstract so the UI can be tested with a fake.
abstract class ScrollLessPlatform {
  Future<bool> isAccessibilityEnabled();
  Future<bool> isServiceRunning();
  Future<void> openAccessibilitySettings();
  Future<bool> getOverlayEnabled();
  Future<void> setOverlayEnabled(bool enabled);
  Future<List<DailyStat>> getTodayStats();
  Future<List<DailyStat>> getHistory(int days);
  Future<List<ReelEvent>> getRecentEvents(int limit);
  Future<void> resetToday();
  Future<void> clearAllData();
  Future<int> getDailyGoal();
  Future<void> setDailyGoal(int goal);
  Future<bool> isWidgetAdded();
  Future<bool> isPinWidgetSupported();

  /// Minimum on-screen time before a video counts, in milliseconds.
  Future<int> getMinWatchMs();
  Future<void> setMinWatchMs(int ms);

  /// Opens the launcher's "add to home screen" sheet for the small or large
  /// widget. Returns false when the launcher does not support pinning.
  Future<bool> requestPinWidget({bool large = false});

  /// Live updates from the accessibility service (today's stats, foreground app).
  Stream<LiveState> get liveState;
}

class MethodChannelScrollLessPlatform implements ScrollLessPlatform {
  MethodChannelScrollLessPlatform({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methods = methodChannel ?? const MethodChannel('dev.chandra.scroll_less/native'),
        _events = eventChannel ?? const EventChannel('dev.chandra.scroll_less/stats');

  final MethodChannel _methods;
  final EventChannel _events;

  @override
  Future<bool> isAccessibilityEnabled() async =>
      await _methods.invokeMethod<bool>('isAccessibilityEnabled') ?? false;

  @override
  Future<bool> isServiceRunning() async => await _methods.invokeMethod<bool>('isServiceRunning') ?? false;

  @override
  Future<void> openAccessibilitySettings() => _methods.invokeMethod<void>('openAccessibilitySettings');

  @override
  Future<bool> getOverlayEnabled() async => await _methods.invokeMethod<bool>('getOverlayEnabled') ?? true;

  @override
  Future<void> setOverlayEnabled(bool enabled) =>
      _methods.invokeMethod<void>('setOverlayEnabled', {'enabled': enabled});

  @override
  Future<List<DailyStat>> getTodayStats() async => _stats(await _methods.invokeListMethod<dynamic>('getTodayStats'));

  @override
  Future<List<DailyStat>> getHistory(int days) async =>
      _stats(await _methods.invokeListMethod<dynamic>('getHistory', {'days': days}));

  @override
  Future<List<ReelEvent>> getRecentEvents(int limit) async {
    final raw = await _methods.invokeListMethod<dynamic>('getRecentEvents', {'limit': limit}) ?? const [];
    return raw.map((e) => ReelEvent.fromMap(e as Map)).toList(growable: false);
  }

  @override
  Future<void> resetToday() => _methods.invokeMethod<void>('resetToday');

  @override
  Future<void> clearAllData() => _methods.invokeMethod<void>('clearAllData');

  @override
  Future<int> getDailyGoal() async => await _methods.invokeMethod<int>('getDailyGoal') ?? 0;

  @override
  Future<void> setDailyGoal(int goal) => _methods.invokeMethod<void>('setDailyGoal', {'goal': goal});

  @override
  Future<bool> isWidgetAdded() async => await _methods.invokeMethod<bool>('isWidgetAdded') ?? false;

  @override
  Future<bool> isPinWidgetSupported() async => await _methods.invokeMethod<bool>('isPinWidgetSupported') ?? false;

  @override
  Future<int> getMinWatchMs() async => await _methods.invokeMethod<int>('getMinWatchMs') ?? 2000;

  @override
  Future<void> setMinWatchMs(int ms) => _methods.invokeMethod<void>('setMinWatchMs', {'ms': ms});

  @override
  Future<bool> requestPinWidget({bool large = false}) async =>
      await _methods.invokeMethod<bool>('requestPinWidget', {'large': large}) ?? false;

  @override
  Stream<LiveState> get liveState =>
      _events.receiveBroadcastStream().map((e) => LiveState.fromMap(e as Map));

  static List<DailyStat> _stats(List<dynamic>? raw) =>
      (raw ?? const []).map((e) => DailyStat.fromMap(e as Map)).toList(growable: false);
}
