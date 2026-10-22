import 'package:flutter/material.dart';

import '../app/app_controller.dart';

/// Google Play "prominent disclosure" for the Accessibility API. Shown before
/// the user is sent to system settings, every time until they accept.
Future<bool> showAccessibilityDisclosure(BuildContext context, AppController controller) async {
  if (controller.disclosureAccepted) {
    await controller.openAccessibilitySettings();
    return true;
  }
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _DisclosureDialog(),
  );
  if (accepted == true) {
    await controller.acceptDisclosure();
    await controller.openAccessibilitySettings();
    return true;
  }
  return false;
}

class _DisclosureDialog extends StatelessWidget {
  const _DisclosureDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      icon: Icon(Icons.accessibility_new_rounded, color: theme.colorScheme.primary, size: 32),
      title: const Text('ScrollLess needs the Accessibility service'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ScrollLess uses Android\'s Accessibility API to notice when a new Instagram Reel '
              'or YouTube Short appears on screen, count it, and measure how long you spend scrolling.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _Point(Icons.visibility_outlined, 'It reads only the Instagram and YouTube screens. Other apps are ignored.'),
            _Point(Icons.phone_android_outlined, 'Counts and times are stored only on this phone, in a local database.'),
            _Point(Icons.cloud_off_outlined, 'Nothing you watch, type or see is collected, shared or sent anywhere.'),
            const SizedBox(height: 12),
            Text(
              'On the next screen, choose ScrollLess under "Installed apps" (or "Downloaded apps") and turn it on.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          child: const Text('Agree & continue'),
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      );
}
