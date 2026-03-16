import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../widgets/freezme_logo.dart';

class DailyRecapPage extends StatefulWidget {
  const DailyRecapPage({super.key});

  @override
  State<DailyRecapPage> createState() => _DailyRecapPageState();
}

class _DailyRecapPageState extends State<DailyRecapPage> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    final matches = flow.matches;
    final newVibes = flow.dailyProfiles.length;
    final videoDates = matches.length;
    final messages = matches.length * 4;
    final profileViews = 20 + matches.length * 2;

    final stats = [
      (
        icon: Icons.favorite,
        label: 'New Vibes',
        value: '$newVibes',
        gradient: const LinearGradient(colors: [FreezmeColors.secondary, FreezmeColors.accent])
      ),
      (
        icon: Icons.videocam,
        label: 'Video Dates',
        value: '$videoDates',
        gradient: const LinearGradient(colors: [FreezmeColors.primary, FreezmeColors.secondary])
      ),
      (
        icon: Icons.message_outlined,
        label: 'Messages',
        value: '$messages',
        gradient: const LinearGradient(colors: [FreezmeColors.accent, FreezmeColors.success])
      ),
      (
        icon: Icons.trending_up,
        label: 'Profile Views',
        value: '$profileViews',
        gradient: const LinearGradient(colors: [Color(0xFF8B5FBF), FreezmeColors.primary])
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    children: [
                      const _StaggeredEntrance(delayIndex: 0, child: FreezmeLogo(size: LogoSize.sm, showText: true)),
                      const SizedBox(height: 20),
                      const _StaggeredEntrance(delayIndex: 1, child: Text('✨', style: TextStyle(fontSize: 56))),
                      const SizedBox(height: 12),
                      _StaggeredEntrance(
                        delayIndex: 2,
                        child: Text(
                          'Your Daily Recap',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: FreezmeColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const _StaggeredEntrance(
                        delayIndex: 3,
                        child: Text(
                          'Your vibe journey is trending up 📈',
                          style: TextStyle(color: FreezmeColors.muted, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Vibe Trend Chart
                      _StaggeredEntrance(
                        delayIndex: 4,
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          child: _VibeTrendChart(),
                        ),
                      ),
                      const SizedBox(height: 32),

                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: stats.length,
                        itemBuilder: (context, index) {
                          final stat = stats[index];
                          return _StaggeredEntrance(
                            delayIndex: 5 + index,
                            child: _GlassCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    height: 48,
                                    width: 48,
                                    decoration: BoxDecoration(
                                      gradient: stat.gradient,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: stat.gradient.colors.first.withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(stat.icon, color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    stat.value,
                                    style: const TextStyle(
                                      color: FreezmeColors.neutral,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    stat.label,
                                    style: const TextStyle(
                                      color: FreezmeColors.muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _StaggeredEntrance(
                        delayIndex: 9,
                        child: _GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Today\'s Highlights',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: FreezmeColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              const _RecapBullet(
                                color: FreezmeColors.primary,
                                text: 'You had a great vibe date that turned into a chat! 💜',
                              ),
                              const SizedBox(height: 12),
                              _RecapBullet(
                                color: FreezmeColors.secondary,
                                text: 'Your Trust Score is now ${flow.trustScore} (+5 today) 🛡️',
                              ),
                              const SizedBox(height: 12),
                              const _RecapBullet(
                                color: FreezmeColors.accent,
                                text: 'Matched with 3 people who share your Explorer archetype! 🎉',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _StaggeredEntrance(
                        delayIndex: 10,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [FreezmeColors.primary, FreezmeColors.secondary],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: FreezmeColors.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: const [
                              Text('💫', style: TextStyle(fontSize: 32)),
                              SizedBox(height: 12),
                              Text(
                                'The best connections happen when you\'re your authentic self 💜',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: _StaggeredEntrance(
                  delayIndex: 11,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: FreezmeColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(64),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 4,
                    ),
                    onPressed: () => flow.returnToPool(resetIndex: true),
                    icon: const Icon(Icons.chevron_right),
                    label: const Text(
                      'Explore Tomorrow\'s Vibes',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _GlassCard({required this.child, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _VibeTrendChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrendPainter(),
    );
  }
}

class _TrendPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = FreezmeColors.primary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final points = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.2, size.height * 0.6),
      Offset(size.width * 0.4, size.height * 0.7),
      Offset(size.width * 0.6, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.4),
      Offset(size.width, size.height * 0.1),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [FreezmeColors.primary.withValues(alpha: 0.3), Colors.transparent],
    );

    canvas.drawPath(fillPath, Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    canvas.drawPath(path, paint);

    // Draw dots
    final dotPaint = Paint()..color = FreezmeColors.primary;
    for (final p in points) {
      canvas.drawCircle(p, 6, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StaggeredEntrance extends StatelessWidget {
  final int delayIndex;
  final Widget child;

  const _StaggeredEntrance({required this.delayIndex, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (delayIndex * 100)),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _RecapBullet extends StatelessWidget {
  const _RecapBullet({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 10,
          width: 10,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: FreezmeColors.neutral, fontWeight: FontWeight.w500, height: 1.4),
          ),
        ),
      ],
    );
  }
}
