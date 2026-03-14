import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme.dart';

class VectorSimulationScreen extends StatefulWidget {
  const VectorSimulationScreen({super.key});

  @override
  State<VectorSimulationScreen> createState() => _VectorSimulationScreenState();
}

class _VectorSimulationScreenState extends State<VectorSimulationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_VectorUser> _users = [];
  final double _meSize = 80;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Generate random users with "Similarity" scores
    final random = math.Random();
    for (int i = 0; i < 20; i++) {
      _users.add(_VectorUser(
        name: 'User $i',
        similarity: 0.3 + random.nextDouble() * 0.7,
        angle: random.nextDouble() * 2 * math.pi,
        initialDistance: 200 + random.nextDouble() * 200,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FreezmeColors.background,
      body: Stack(
        children: [
          // Background Grid
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(),
            ),
          ),

          // Central "ME" 
          Center(
            child: Container(
              width: _meSize,
              height: _meSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: FreezmeGradients.primary,
                boxShadow: [
                  BoxShadow(
                    color: FreezmeColors.primary.withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 40),
            ),
          ),

          // Users orbiting and being "pulled"
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                children: _users.map((user) {
                  // Calculate dynamic position
                  // Distance reduces as similarity increases
                  final targetDistance = (1.0 - user.similarity) * 300;
                  final currentDistance = user.initialDistance - 
                      ((user.initialDistance - targetDistance) * 
                       math.min(1.0, _controller.value * 2));
                  
                  final x = math.cos(user.angle) * currentDistance;
                  final y = math.sin(user.angle) * currentDistance;

                  return Center(
                    child: Transform.translate(
                      offset: Offset(x, y),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.lerp(
                                FreezmeColors.muted,
                                FreezmeColors.primary,
                                user.similarity,
                              ),
                              boxShadow: [
                                if (user.similarity > 0.8)
                                  BoxShadow(
                                    color: FreezmeColors.primary.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                  ),
                              ],
                            ),
                          ),
                          if (user.similarity > 0.85)
                            Text(
                              '${(user.similarity * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // HUD Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Vector Matching Simulation',
                    style: FreezmeTypography.title.copyWith(color: Colors.white),
                  ),
                  const Text(
                    'Simulating sub-second cosine similarity\nacross 10k+ local embeddings...',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt, color: Colors.amber),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'High-Similarity leads are pulled into your 7 AM Daily Pool automatically.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VectorUser {
  final String name;
  final double similarity;
  final double angle;
  final double initialDistance;

  _VectorUser({
    required this.name,
    required this.similarity,
    required this.angle,
    required this.initialDistance,
  });
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
    
    // Circles
    final center = Offset(size.width / 2, size.height / 2);
    for (double r = 100; r < 400; r += 100) {
      canvas.drawCircle(center, r, paint..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
