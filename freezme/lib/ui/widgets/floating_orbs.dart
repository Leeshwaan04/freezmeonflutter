import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

class FloatingOrbs extends StatelessWidget {
  const FloatingOrbs({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final angle = progress * math.pi * 2;
    final secondaryAngle = (progress + 0.35) * math.pi * 2;
    final tertiaryAngle = (progress + 0.7) * math.pi * 2;

    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned(
              top: 90 + math.sin(angle) * 24,
              left: -60 + math.cos(angle) * 30,
              child: const GlowingOrb(
                size: 220,
                colors: [FreezmeColors.secondary, FreezmeColors.surfaceAlt],
                opacity: 0.35,
              ),
            ),
            Positioned(
              bottom: 140 + math.cos(secondaryAngle) * 28,
              right: -50 + math.sin(secondaryAngle) * 32,
              child: const GlowingOrb(
                size: 180,
                colors: [FreezmeColors.accent, FreezmeColors.surface],
                opacity: 0.3,
              ),
            ),
            Positioned(
              top: 200 + math.sin(tertiaryAngle) * 36,
              right: 80 + math.cos(tertiaryAngle) * 24,
              child: const GlowingOrb(
                size: 140,
                colors: [FreezmeColors.primary, FreezmeColors.surfaceAlt],
                opacity: 0.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlowingOrb extends StatelessWidget {
  const GlowingOrb({
    super.key,
    required this.size,
    required this.colors,
    required this.opacity,
  });

  final double size;
  final List<Color> colors;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            colors.first.withValues(alpha: opacity),
            colors.last.withValues(alpha: 0.05),
          ],
          stops: const [0, 1],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: opacity),
            blurRadius: size * 0.35,
            spreadRadius: size * 0.08,
          ),
        ],
      ),
    );
  }
}
