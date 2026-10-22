import 'package:shared_preferences/shared_preferences.dart';

/// Small on-device flags (onboarding state, disclosure consent). No analytics.
abstract class AppPreferences {
  Future<bool> get onboardingDone;
  Future<void> setOnboardingDone(bool value);
  Future<bool> get disclosureAccepted;
  Future<void> setDisclosureAccepted(bool value);
}

class SharedAppPreferences implements AppPreferences {
  static const _kOnboarding = 'onboarding_done';
  static const _kDisclosure = 'accessibility_disclosure_accepted';

  Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  @override
  Future<bool> get onboardingDone async => (await _p).getBool(_kOnboarding) ?? false;

  @override
  Future<void> setOnboardingDone(bool value) async => (await _p).setBool(_kOnboarding, value);

  @override
  Future<bool> get disclosureAccepted async => (await _p).getBool(_kDisclosure) ?? false;

  @override
  Future<void> setDisclosureAccepted(bool value) async => (await _p).setBool(_kDisclosure, value);
}

class InMemoryAppPreferences implements AppPreferences {
  bool _onboarding = false;
  bool _disclosure = false;

  @override
  Future<bool> get onboardingDone async => _onboarding;
  @override
  Future<void> setOnboardingDone(bool value) async => _onboarding = value;
  @override
  Future<bool> get disclosureAccepted async => _disclosure;
  @override
  Future<void> setDisclosureAccepted(bool value) async => _disclosure = value;
}
