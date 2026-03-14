import 'dart:math' as math;
import 'package:flutter/material.dart';

class VibeSparkle extends StatefulWidget {
  final Widget child;
  const VibeSparkle({super.key, required this.child});

  @override
  State<VibeSparkle> createState() => _VibeSparkleState();
}

class _VibeSparkleState extends State<VibeSparkle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = List.generate(30, (_) => _Particle());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          foregroundPainter: _SparklePainter(_particles, _controller.value),
          child: widget.child,
        );
      },
    );
  }
}

class _Particle {
  late double x;
  late double y;
  late double vx;
  late double vy;
  late double size;
  late Color color;

  _Particle() {
    final rand = math.Random();
    x = 0;
    y = 0;
    final angle = rand.nextDouble() * 2 * math.pi;
    final speed = rand.nextDouble() * 150 + 50;
    vx = math.cos(angle) * speed;
    vy = math.sin(angle) * speed;
    size = rand.nextDouble() * 4 + 2;
    color = [
      Colors.purpleAccent,
      Colors.blueAccent,
      Colors.white,
      Colors.pinkAccent,
    ][rand.nextInt(4)];
  }
}

class _SparklePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _SparklePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final alpha = (1.0 - progress).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: alpha);
      
      final pos = center + Offset(p.vx * progress, p.vy * progress);
      canvas.drawCircle(pos, p.size, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => true;
}

class ShatterTransition extends StatefulWidget {
  final Widget child;
  const ShatterTransition({super.key, required this.child});

  @override
  State<ShatterTransition> createState() => _ShatterTransitionState();
}

class _ShatterTransitionState extends State<ShatterTransition> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_controller.value == 0) return widget.child;
        
        return Stack(
          children: [
            for (int i = 0; i < 9; i++)
              _buildShatterPiece(i),
          ],
        );
      },
    );
  }

  Widget _buildShatterPiece(int index) {
    final row = index ~/ 3;
    final col = index % 3;
    final rand = math.Random(index);
    
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final angle = (rand.nextDouble() - 0.5) * progress * 2;
          final offset = Offset(
            (rand.nextDouble() - 0.5) * 500 * progress,
            (rand.nextDouble() - 0.5) * 500 * progress,
          );

          return Transform.translate(
            offset: offset,
            child: Transform.rotate(
              angle: angle,
              child: Opacity(
                opacity: (1.0 - progress).clamp(0.0, 1.0),
                child: ClipRect(
                  clipper: _PieceClipper(row, col),
                  child: widget.child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void start() => _controller.forward();
}

class _PieceClipper extends CustomClipper<Rect> {
  final int row;
  final int col;

  _PieceClipper(this.row, this.col);

  @override
  Rect getClip(Size size) {
    final w = size.width / 3;
    final h = size.height / 3;
    return Rect.fromLTWH(col * w, row * h, w, h);
  }

  @override
  bool shouldReclip(_PieceClipper oldClipper) => false;
}
