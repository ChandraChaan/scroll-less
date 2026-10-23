import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Looping "endless feed" illustration: cards slide upward forever while a
/// pause badge pulses. Pure Flutter, no GIF asset, so it stays crisp at any
/// size and in both themes. Honors reduced-motion settings by freezing.
class FeedAnimation extends StatefulWidget {
  const FeedAnimation({super.key, this.size = 96, this.cardColor, this.badgeColor = Brand.coral});

  final double size;
  final Color? cardColor;
  final Color badgeColor;

  @override
  State<FeedAnimation> createState() => _FeedAnimationState();
}

class _FeedAnimationState extends State<FeedAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce && _c.isAnimating) _c.stop();
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(
            painter: _FeedPainter(
              t: _c.value,
              card: widget.cardColor ?? Colors.white,
              badge: widget.badgeColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedPainter extends CustomPainter {
  _FeedPainter({required this.t, required this.card, required this.badge});
  final double t;
  final Color card;
  final Color badge;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cardW = w * 0.56;
    final cardH = h * 0.30;
    final gap = h * 0.08;
    final step = cardH + gap;
    final left = (w - cardW) / 2;

    // Three cards cycling upward. Phase in [0,1) maps to one step of travel.
    final phase = t;
    for (var i = -1; i <= 2; i++) {
      final y = h * 0.52 + (i - phase) * step - cardH / 2;
      final centre = h * 0.52;
      final dist = ((y + cardH / 2) - centre).abs() / step;
      final focus = (1 - dist).clamp(0.0, 1.0);
      final opacity = 0.18 + 0.82 * Curves.easeInOut.transform(focus);
      final scale = 0.9 + 0.1 * focus;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w / 2, y + cardH / 2), width: cardW * scale, height: cardH * scale),
        Radius.circular(cardH * 0.3),
      );
      canvas.drawRRect(rect, Paint()..color = card.withValues(alpha: opacity));
      if (focus > 0.6) {
        // play glyph on the focused card
        final cx = w / 2;
        final cy = y + cardH / 2;
        final s = cardH * 0.28 * scale;
        final path = Path()
          ..moveTo(cx - s * 0.6, cy - s)
          ..lineTo(cx + s * 0.9, cy)
          ..lineTo(cx - s * 0.6, cy + s)
          ..close();
        canvas.drawPath(path, Paint()..color = const Color(0xFF4338CA).withValues(alpha: (focus - 0.6) / 0.4));
      }
    }

    // Pulsing pause badge, bottom-right.
    final pulse = 1 + 0.06 * math.sin(t * 2 * math.pi);
    final r = w * 0.15 * pulse;
    final bc = Offset(left + cardW + w * 0.02, h * 0.74);
    canvas.drawCircle(bc, r + w * 0.025, Paint()..color = card);
    canvas.drawCircle(bc, r, Paint()..color = badge);
    final barW = r * 0.26;
    final barH = r * 0.95;
    for (final dx in [-r * 0.28, r * 0.28]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: bc + Offset(dx, 0), width: barW, height: barH), Radius.circular(barW / 2)),
        Paint()..color = card,
      );
    }
  }

  @override
  bool shouldRepaint(_FeedPainter old) => old.t != t || old.card != card || old.badge != badge;
}

/// Animates an integer from its previous value to the new one.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({super.key, required this.value, required this.style, this.duration = const Duration(milliseconds: 700)});
  final int value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: value.toDouble()),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => Text('${v.round()}', style: style),
      );
}

/// Circular goal progress with the animation in the middle.
class GoalRing extends StatelessWidget {
  const GoalRing({super.key, required this.progress, required this.size, required this.child, this.track, this.color});
  final double progress; // 0..1 (may exceed 1)
  final double size;
  final Widget child;
  final Color? track;
  final Color? color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (_, v, c) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(v, track ?? Colors.white24, color ?? (progress > 1 ? const Color(0xFFFF3B30) : Brand.coral)),
            child: Center(child: c),
          ),
        ),
        child: child,
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.track, this.color);
  final double v;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.07;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(rect, 0, 2 * math.pi, false, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = stroke);
    if (v > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * v, false,
          Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.v != v || old.color != color || old.track != track;
}
