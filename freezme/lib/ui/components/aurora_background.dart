import 'dart:math';
import 'package:flutter/material.dart';
import '../design_system.dart';

class AuroraBackground extends StatefulWidget {
  final Widget child;

  const AuroraBackground({Key? key, required this.child}) : super(key: key);

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background Base
        Container(color: const Color(0xFFFFF5F8)), // Soft Pink Base
        
        // Animated Aurora
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _AuroraPainter(_controller.value),
              size: Size.infinite,
            );
          },
        ),
        
        // Glass Overlay (optional)
        // Container(color: Colors.white.withOpacity(0.3)),

        // Content
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double progress;
  final Random _random = Random(42); // Fixed seed for consistent shapes

  _AuroraPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

    void drawBlob(Color color, double x, double y, double radius) {
      paint.color = color.withValues(alpha: 0.4);
      // Animate position slightly based on progress
      final dx = x + sin(progress * 2 * pi) * 20;
      final dy = y + cos(progress * 2 * pi) * 20;
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }

    // Top Left - Purple
    drawBlob(FreezmeDesignSystem.primary, size.width * 0.2, size.height * 0.2, 120);

    // Top Right - Teal/Blue (Ice feel)
    drawBlob(const Color(0xFF00C6FF), size.width * 0.8, size.height * 0.15, 100);

    // Center - Pink
    drawBlob(const Color(0xFFFF69B4), size.width * 0.5, size.height * 0.4, 140);

    // Bottom Left - Deep Purple
    drawBlob(FreezmeDesignSystem.primaryDark, size.width * 0.1, size.height * 0.7, 150);

    // Bottom Right - Soft Lavender
    drawBlob(const Color(0xFFE0C3FC), size.width * 0.9, size.height * 0.8, 130);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => true;
}
