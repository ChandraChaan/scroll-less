import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_controller.dart';
import '../theme/app_theme.dart';
import 'accessibility_disclosure.dart';
import 'feed_animation.dart';

/// Guided setup: accessibility service (required), home-screen widget
/// (recommended) and daily goal (optional). Reused by onboarding, the Home
/// setup card and Settings.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, required this.controller, this.onDone, this.showDone = true});

  final AppController controller;
  final VoidCallback? onDone;
  final bool showDone;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final theme = Theme.of(context);
        final serviceOn = c.accessibilityEnabled == true;
        final doneCount = [serviceOn, c.widgetAdded, c.dailyGoal > 0].where((b) => b).length;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: Brand.gradient,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                    ),
                    padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 12, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (Navigator.of(context).canPop())
                              IconButton(
                                onPressed: () => Navigator.of(context).maybePop(),
                                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
                              child: Text('$doneCount of 3 done', style: theme.textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Set up ScrollLess',
                                      style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Three quick steps. Only the first one is required; the others make the app much more useful.',
                                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.88), height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const FeedAnimation(size: 92),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  sliver: SliverList.list(
                    children: [
                      SetupStepCard(
                        step: 1,
                        icon: Icons.accessibility_new_rounded,
                        color: Brand.indigo,
                        title: 'Turn on the accessibility service',
                        badge: 'Required',
                        description:
                            'This is how ScrollLess sees a new Reel or Short appear. It reads only the Instagram and YouTube screens; nothing leaves your phone.',
                        done: serviceOn,
                        doneText: 'On · counting Reels and Shorts',
                        actionLabel: serviceOn ? 'Open settings' : 'Turn on',
                        onAction: () => showAccessibilityDisclosure(context, c),
                        steps: const [
                          'Tap "Turn on" and agree to the disclosure',
                          'In Android Settings, open Installed apps (or Downloaded apps)',
                          'Choose ScrollLess and switch it on',
                        ],
                      ),
                      const SizedBox(height: 12),
                      SetupStepCard(
                        step: 2,
                        icon: Icons.widgets_rounded,
                        color: Brand.coral,
                        title: 'Add the home-screen widget',
                        badge: 'Recommended',
                        description: 'Today\'s count, scrolling time and goal progress at a glance, without opening the app.',
                        done: c.widgetAdded,
                        doneText: 'Added to your home screen',
                        actionLabel: c.widgetAdded ? 'Add another' : 'Add widget',
                        onAction: () => _pickWidgetSize(context, c),
                        preview: const _WidgetPreview(),
                      ),
                      const SizedBox(height: 12),
                      SetupStepCard(
                        step: 3,
                        icon: Icons.flag_rounded,
                        color: Brand.mint,
                        title: 'Set a daily goal',
                        badge: 'Optional',
                        description: 'Pick how many short videos a day feels right. The floating counter and widget turn amber near the goal and red above it.',
                        done: c.dailyGoal > 0,
                        doneText: c.dailyGoal > 0 ? 'Goal: ${c.dailyGoal} videos a day' : '',
                        actionLabel: c.dailyGoal > 0 ? 'Change goal' : 'Set goal',
                        onAction: () => showGoalDialog(context, c),
                      ),
                      if (showDone) ...[
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const Key('setup-done'),
                          onPressed: () {
                            if (onDone != null) {
                              onDone!();
                            } else {
                              Navigator.of(context).maybePop();
                            }
                          },
                          child: Text(serviceOn ? 'Done' : 'Continue without counting'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Lets the user choose the small or large widget, then opens the launcher's pin sheet.
Future<void> _pickWidgetSize(BuildContext context, AppController c) async {
  final large = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Choose a size', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.crop_square_rounded),
            title: const Text('Small · 2 × 2'),
            subtitle: const Text('Count and goal progress'),
            onTap: () => Navigator.pop(ctx, false),
          ),
          ListTile(
            leading: const Icon(Icons.crop_landscape_rounded),
            title: const Text('Large · 4 × 3'),
            subtitle: const Text('Count, time, Instagram and YouTube split, goal'),
            onTap: () => Navigator.pop(ctx, true),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (large == null || !context.mounted) return;
  final shown = await c.requestPinWidget(large: large);
  if (!shown && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Your launcher does not support adding widgets from apps. Long-press your home screen → Widgets → ScrollLess.'),
    ));
  }
}

class SetupStepCard extends StatelessWidget {
  const SetupStepCard({
    super.key,
    required this.step,
    required this.icon,
    required this.color,
    required this.title,
    required this.badge,
    required this.description,
    required this.done,
    required this.doneText,
    required this.actionLabel,
    required this.onAction,
    this.steps = const [],
    this.preview,
  });

  final int step;
  final IconData icon;
  final Color color;
  final String title;
  final String badge;
  final String description;
  final bool done;
  final String doneText;
  final String actionLabel;
  final VoidCallback onAction;
  final List<String> steps;
  final Widget? preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: done ? Brand.mint.withValues(alpha: 0.7) : scheme.outlineVariant.withValues(alpha: 0.6), width: done ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _Pill(text: 'Step $step', color: scheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          _Pill(text: badge, color: color),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: done
                      ? Container(
                          key: const ValueKey('done'),
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Brand.mint, shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                        )
                      : const SizedBox(key: ValueKey('todo'), width: 30),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
            if (preview != null) ...[const SizedBox(height: 12), preview!],
            if (steps.isNotEmpty && !done) ...[
              const SizedBox(height: 10),
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}.  ', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
                      Expanded(child: Text(steps[i], style: theme.textTheme.bodySmall)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                if (done)
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Brand.mint, size: 18),
                        const SizedBox(width: 6),
                        Expanded(child: Text(doneText, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                done
                    ? OutlinedButton(
                        onPressed: onAction,
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), padding: const EdgeInsets.symmetric(horizontal: 16)),
                        child: Text(actionLabel),
                      )
                    : FilledButton(
                        onPressed: onAction,
                        style: FilledButton.styleFrom(backgroundColor: color, minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 20)),
                        child: Text(actionLabel),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
      );
}

/// Static mock of the widget so users know what they are adding.
class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(gradient: Brand.gradient, borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Brand.coral, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('TODAY', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('24m', style: theme.textTheme.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('37', style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('short videos', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: 0.74, minHeight: 6, backgroundColor: Colors.white24, color: Brand.coral),
          ),
          const SizedBox(height: 6),
          Text('Instagram 21  ·  YouTube 16  ·  goal 50', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

/// Slider dialog for the daily goal. 0 = no goal.
Future<void> showGoalDialog(BuildContext context, AppController c) async {
  var value = c.dailyGoal == 0 ? 30 : c.dailyGoal;
  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Daily goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$value', style: Theme.of(ctx).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
            Text('short videos a day', style: Theme.of(ctx).textTheme.bodyMedium),
            Slider(
              value: value.toDouble(),
              min: 5,
              max: 200,
              divisions: 39,
              label: '$value',
              onChanged: (v) => setState(() => value = v.round()),
            ),
            Text('Most people land between 20 and 60.', style: Theme.of(ctx).textTheme.bodySmall),
          ],
        ),
        actions: [
          if (c.dailyGoal > 0) TextButton(onPressed: () => Navigator.pop(ctx, 0), child: const Text('Remove goal')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, value),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (result != null) await c.setDailyGoal(result);
}
