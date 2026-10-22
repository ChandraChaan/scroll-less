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
  Stream<LiveState> get liveState =>
      _events.receiveBroadcastStream().map((e) => LiveState.fromMap(e as Map));

  static List<DailyStat> _stats(List<dynamic>? raw) =>
      (raw ?? const []).map((e) => DailyStat.fromMap(e as Map)).toList(growable: false);
}
