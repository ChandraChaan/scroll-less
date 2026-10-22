import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import 'accessibility_disclosure.dart';
import 'privacy_screen.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller, required this.appVersion});
  final AppController controller;
  final String appVersion;

  Future<void> _confirm(BuildContext context, String title, String body, Future<void> Function() action, {String confirmLabel = 'Continue'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (ok == true) await action();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final scheme = Theme.of(context).colorScheme;
        final enabled = c.accessibilityEnabled;
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              SectionTitle('Tracking'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.accessibility_new_rounded, color: enabled == true ? scheme.primary : scheme.error),
                      title: const Text('Accessibility service'),
                      subtitle: Text(enabled == null ? 'Checking…' : (enabled ? 'On · counting Reels and Shorts' : 'Off · counting is paused')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showAccessibilityDisclosure(context, c),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: const Icon(Icons.picture_in_picture_alt_outlined),
                      title: const Text('Floating counter'),
                      subtitle: const Text('Show today\'s count and time over Instagram and YouTube'),
                      value: c.overlayEnabled,
                      onChanged: c.setOverlayEnabled,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SectionTitle('Your data'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.restart_alt_rounded),
                      title: const Text('Reset today'),
                      subtitle: const Text('Clear today\'s counts and times; other days are kept'),
                      onTap: () => _confirm(context, 'Reset today?', 'Today\'s counts and times will be deleted. Other days are kept.', c.resetToday, confirmLabel: 'Reset'),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.delete_forever_rounded, color: scheme.error),
                      title: Text('Delete all data', style: TextStyle(color: scheme.error)),
                      subtitle: const Text('Remove every count, time and detection from this phone'),
                      onTap: () => _confirm(context, 'Delete all data?', 'Every count, time and detection stored on this device will be removed. This cannot be undone.', c.clearAllData, confirmLabel: 'Delete'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SectionTitle('Privacy & about'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_outline_rounded),
                      title: const Text('Privacy policy'),
                      subtitle: const Text('Everything stays on your phone'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PrivacyScreen())),
                    ),
                    const Divider(indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('Version'),
                      subtitle: Text(appVersion),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
