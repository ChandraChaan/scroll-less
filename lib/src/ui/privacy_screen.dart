import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public privacy policy URL (also linked from the Play listing).
const privacyPolicyUrl = 'https://scroll-less-chandra.web.app/privacy';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text('ScrollLess is built to keep your activity on your phone.', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _h(theme, 'What the app accesses'),
          _p(theme,
              'ScrollLess uses Android\'s Accessibility API to observe the Instagram and YouTube screens. It uses this to detect when a new Reel or Short is shown and to measure how long those screens are visible. For every other app it only receives the package name of the window that came to the front, so it can stop the timers; their content is never read.'),
          _h(theme, 'What is stored'),
          _p(theme,
              'Per-day counts and durations for Instagram and YouTube, plus one row per counted video containing a timestamp and a short hash derived from the words on screen. The words themselves are never stored. All of this lives in a local SQLite database inside the app\'s private storage and can be deleted at any time from Settings.'),
          _h(theme, 'What leaves the device'),
          _p(theme,
              'Only crash reports, sent to Firebase Crashlytics, containing a stack trace, device model, OS version, app version and an installation identifier. No screen content, counts, or account information are ever transmitted. ScrollLess has no account system, no analytics, and no advertising.'),
          _h(theme, 'Permissions'),
          _p(theme,
              'Accessibility service: required to count videos and track time. Internet: used only for crash reports. ScrollLess does not request location, contacts, storage, camera, microphone or notification permissions.'),
          _h(theme, 'Children'),
          _p(theme, 'ScrollLess is not directed at children under 13 and collects no personal data from anyone.'),
          _h(theme, 'Changes and contact'),
          _p(theme, 'Updates to this policy are published at the address below and in the app. Questions: open an issue on the project\'s GitHub repository or email the developer address shown on the Play Store listing.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.parse(privacyPolicyUrl), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open the online version'),
          ),
        ],
      ),
    );
  }

  Widget _h(ThemeData t, String s) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(s, style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      );

  Widget _p(ThemeData t, String s) => Text(s, style: t.textTheme.bodyMedium?.copyWith(height: 1.45));
}
