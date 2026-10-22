import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'src/app/app_controller.dart';
import 'src/data/preferences.dart';
import 'src/data/stats_repository.dart';
import 'src/native/scrollless_platform.dart';
import 'src/theme/app_theme.dart';
import 'src/ui/app_shell.dart';
import 'src/ui/onboarding_screen.dart';

const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.1.0');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Crashlytics is the only network-facing component of the app and only ever
  // receives stack traces. It is disabled for debug builds.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  final preferences = SharedAppPreferences();
  final controller = AppController(
    platform: MethodChannelScrollLessPlatform(),
    repository: SqliteStatsRepository(),
    preferences: preferences,
  );
  final onboarded = await preferences.onboardingDone;

  runApp(ScrollLessApp(controller: controller, showOnboarding: !onboarded));
}

class ScrollLessApp extends StatefulWidget {
  const ScrollLessApp({super.key, required this.controller, required this.showOnboarding});
  final AppController controller;
  final bool showOnboarding;

  @override
  State<ScrollLessApp> createState() => _ScrollLessAppState();
}

class _ScrollLessAppState extends State<ScrollLessApp> {
  late bool _onboarding = widget.showOnboarding;

  @override
  void initState() {
    super.initState();
    widget.controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScrollLess',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: _onboarding
          ? OnboardingScreen(controller: widget.controller, onDone: () => setState(() => _onboarding = false))
          : AppShell(controller: widget.controller, appVersion: appVersion),
    );
  }
}
