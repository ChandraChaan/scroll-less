import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../theme/app_theme.dart';
import 'accessibility_disclosure.dart';

/// Three-step first-run flow: what the app does, how privacy works, enable
/// the service. Finishes with the accessibility disclosure.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.controller,
    required this.onDone,
  });

  final AppController controller;
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _steps = [
    _Step(
      icon: Icons.play_circle_outline_rounded,
      title: 'Know how much you scroll',
      body:
          'ScrollLess counts every Instagram Reel and YouTube Short you watch and shows a live counter right over the app.',
    ),
    _Step(
      icon: Icons.timer_outlined,
      title: 'Time, per app',
      body:
          'See how long you spend on Reels and Shorts each day, separately for Instagram and YouTube, with a 30-day history.',
    ),
    _Step(
      icon: Icons.lock_outline_rounded,
      title: 'Private by design',
      body:
          'Everything stays on your phone in a local database. No account, no sync, no ads, no analytics. Only crash reports leave the device.',
    ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await widget.controller.preferences.setOnboardingDone(true);
    if (!mounted) return;
    await showAccessibilityDisclosure(context, widget.controller);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _index == _steps.length - 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: Brand.gradient),
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                    ),
                    child: const Text('Skip'),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _steps.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => _StepView(step: _steps[i]),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _steps.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _index ? Colors.white : Colors.white38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: FilledButton(
                    key: const Key('onboarding-next'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Brand.indigoDeep,
                    ),
                    onPressed: last
                        ? _finish
                        : () => _pages.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                    child: Text(last ? 'Enable ScrollLess' : 'Continue'),
                  ),
                ),
                if (last)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'You will be asked to turn on the Accessibility service next.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step {
  const _Step({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
}

class _StepView extends StatelessWidget {
  const _StepView({required this.step});
  final _Step step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(step.icon, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 36),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            step.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
