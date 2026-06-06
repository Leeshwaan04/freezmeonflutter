import 'package:flutter/material.dart';
import '../design_system.dart';

/// Shared in-app background: a calm, static **frosted-glass** backdrop.
///
/// Glassmorphism that stays on-brand for a "frozen / ice" app — a soft surface
/// gradient with a few large, heavily-blurred brand-tint orbs, softened under a
/// translucent frosted veil so they read as gentle pastel frost. It is fully
/// STATIC (no animation, and no live `BackdropFilter` that would jank behind
/// scrolling content), so it looks like premium frosted glass while keeping
/// text contrast high and costing nothing per frame.
///
/// Splash + auth keep their own animated entry and do NOT use this widget, so
/// the first impression still moves while the working app stays calm.
/// (Named `AuroraBackground` for call-site compatibility; rename to
/// `AppBackground` in the design-system pass.)
class AuroraBackground extends StatelessWidget {
  final Widget child;

  /// Kept for call-site compatibility. The backdrop is identical for all users.
  final bool isPremium;

  const AuroraBackground({
    super.key,
    required this.child,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Soft surface gradient base.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                FreezmeDesignSystem.surface, // creamy off-white
                FreezmeDesignSystem.surfaceAlt, // whisper of purple
              ],
            ),
          ),
        ),

        // 2. Static, heavily-blurred brand orbs — the colour the frost refracts.
        const CustomPaint(painter: _FrostOrbsPainter()),

        // 3. Frosted veil — translucent white (with a faint top sheen) softens
        //    the orbs into glass and keeps content legible.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.46),
                Colors.white.withValues(alpha: 0.30),
              ],
            ),
          ),
        ),

        // 4. Content.
        child,
      ],
    );
  }
}

/// Paints a few large, soft, low-saturation brand orbs. Static (never repaints)
/// — depth/colour for the frosted veil above, not the old animated rainbow.
class _FrostOrbsPainter extends CustomPainter {
  const _FrostOrbsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    void orb(Color color, double fx, double fy, double radius) {
      paint.color = color;
      canvas.drawCircle(
        Offset(size.width * fx, size.height * fy),
        radius,
        paint,
      );
    }

    orb(FreezmeDesignSystem.primary.withValues(alpha: 0.16), 0.16, 0.14, 150);
    orb(const Color(0xFFB39DDB).withValues(alpha: 0.18), 0.88, 0.28, 150); // lavender
    orb(const Color(0xFF9FD8E8).withValues(alpha: 0.14), 0.28, 0.84, 160); // soft ice-blue
    orb(FreezmeDesignSystem.primaryDark.withValues(alpha: 0.10), 0.82, 0.88, 150);
  }

  @override
  bool shouldRepaint(covariant _FrostOrbsPainter oldDelegate) => false;
}
