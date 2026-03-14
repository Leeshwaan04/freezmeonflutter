import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../../models/profile.dart';
import '../../core/app_stage.dart';

class CircleDiscoveryPage extends StatefulWidget {
  const CircleDiscoveryPage({super.key});

  @override
  State<CircleDiscoveryPage> createState() => _CircleDiscoveryPageState();
}

class _CircleDiscoveryPageState extends State<CircleDiscoveryPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    // Simulate active scanning
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isScanning = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    final missionTheme = MissionTheme.fromArchetype(flow.selectedArchetype);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Premium Mindset Map Background
          Positioned.fill(
            child: CustomPaint(
              painter: MindsetMapPainter(
                animationValue: _controller.value,
                baseColor: missionTheme.accentColor,
              ),
            ),
          ),

          // 2. Glassmorphism HUD Overlay
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, flow),
                const SizedBox(height: 24),
                Expanded(
                  child: _isScanning 
                      ? _buildScanningState(context) 
                      : _buildCirclesList(context, flow, missionTheme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppFlowController flow) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: flow.pop,
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          const SizedBox(height: 16),
          const Text(
            'Social Escapes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          Text(
            'Local 5km Mindset Clusters',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildRadarAnimation(),
          const SizedBox(height: 48),
          const Text(
            'Triangulating Mindsets...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Finding 4-6 people nearby with high vibe sync.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarAnimation() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            for (int i = 0; i < 3; i++)
              Transform.scale(
                scale: 1.0 + (_controller.value + i / 3.0) % 1.0,
                child: Opacity(
                  opacity: 1.0 - (_controller.value + i / 3.0) % 1.0,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                  ),
                ),
              ),
            const Icon(Icons.gps_fixed, color: Colors.white, size: 40),
          ],
        );
      },
    );
  }

  Widget _buildCirclesList(BuildContext context, AppFlowController flow, MissionTheme theme) {
    final mockCircles = [
      VibeCircle(
        id: 'c1',
        name: 'Morning Session Squad',
        archetype: LifestyleArchetype.gym,
        createdAt: DateTime.now(),
      ),
      VibeCircle(
        id: 'c2',
        name: 'Post-Workout Fuel',
        archetype: LifestyleArchetype.brunch,
        createdAt: DateTime.now(),
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: mockCircles.length,
      itemBuilder: (context, index) {
        return _buildCircleCard(context, flow, mockCircles[index], index);
      },
    );
  }

  Widget _buildCircleCard(BuildContext context, AppFlowController flow, VibeCircle circle, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildMemberAvatars(),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '🔥 HIGH SYNC',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    circle.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '5 members • within 1.2km of you',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => flow.joinCircle(circle),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: FreezmeColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Join Social Escape',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemberAvatars() {
    return SizedBox(
      width: 100,
      height: 40,
      child: Stack(
        children: [
          for (int i = 0; i < 4; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white12, width: 2),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(
                    'https://i.pravatar.cc/150?u=${i + 100}',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MindsetMapPainter extends CustomPainter {
  final double animationValue;
  final Color baseColor;

  MindsetMapPainter({required this.animationValue, required this.baseColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          baseColor.withValues(alpha: 0.8),
          baseColor.withValues(alpha: 0.4),
          Colors.black,
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, paint);

    // Draw Grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Draw Animated Mindset Nodes
    final nodePaint = Paint()..color = Colors.white.withValues(alpha: 0.1);
    final rand = math.Random(42);
    for (int i = 0; i < 15; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final radius = 20.0 + math.sin(animationValue * math.pi * 2 + i) * 10;
      canvas.drawCircle(Offset(x, y), radius, nodePaint);
      
      // Connect nodes occasionally
      if (i > 0 && rand.nextBool()) {
        canvas.drawLine(
          Offset(x, y),
          Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height),
          gridPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(MindsetMapPainter oldDelegate) => true;
}
