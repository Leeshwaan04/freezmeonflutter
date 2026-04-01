import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../../models/vibe_profile.dart';
import '../widgets/freezme_logo.dart';
import '../widgets/freeze_modal.dart';
import '../../core/app_stage.dart';
import '../../models/blueprint.dart';

class DailyVibePoolPage extends StatefulWidget {
  const DailyVibePoolPage({super.key});

  @override
  State<DailyVibePoolPage> createState() => _DailyVibePoolPageState();
}

class _DailyVibePoolPageState extends State<DailyVibePoolPage> {

  Future<void> _handleVibe(
    BuildContext context,
    AppFlowController flow,
    VibeProfile profile,
  ) async {
    if (flow.vibeCredits <= 0 && !flow.isPremium) {
      _trackEvent('upsell_triggered_out_of_credits', {'context': 'pool_vibe'});
      flow.openFreezmePlus();
      return;
    }

    _trackEvent('vibe_sent', {
      'profile_id': profile.id,
      'remaining_credits': flow.vibeCredits - 1
    });
    flow.consumeCredit(); // Deduct credit
    flow.matchProfile(profile);
  }

  void _trackEvent(String name, Map<String, dynamic> props) {
    debugPrint('ANALYTICS [EVENT]: $name | PROPS: $props');
  }

  String _getNudgeText(LifestyleArchetype? userMission, VibeProfile profile) {
    if (userMission == null) return "Want to explore some vibes? ✨";

    final hasOverlap = profile.archetypes.contains(userMission);

    final n = profile.name.split(' ').first;
    switch (userMission) {
      case LifestyleArchetype.gym:
        return hasOverlap
            ? "$n is ready for a workout partner or friendly rivalry 🎾"
            : "$n is more into ${profile.archetypes.isNotEmpty ? profile.archetypes.first.name : 'other'} vibes — opposites can spark! 🥦";
      case LifestyleArchetype.brunch:
        return hasOverlap
            ? "$n knows the best spots in town. Sunday brunch? 🥂"
            : "$n has a different vibe, but a good coffee chat never hurts ☕";
      case LifestyleArchetype.clubbing:
        return hasOverlap
            ? "$n knows every good spot in the city. Dance? 🎶"
            : "$n is a bit more low-key, but worth the vibe check! ✨";
      case LifestyleArchetype.travel:
        return hasOverlap
            ? "$n is also an explorer! Weekend trek or road trip? 🎒"
            : "$n prefers staying in, but deep conversations are guaranteed 🏠";
      case LifestyleArchetype.homebody:
        return hasOverlap
            ? "$n loves a cozy night and deep talks. Perfect slow weekend match 🏠"
            : "$n is higher energy, but opposites attract! ⚡";
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    return AnimatedBuilder(
      animation: flow,
      builder: (context, _) {
        final VibeProfile profile = flow.currentProfile;
        final int remaining = flow.remainingProfiles;
        final missionTheme = MissionTheme.fromArchetype(flow.selectedArchetype);

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  missionTheme.accentColor.withValues(alpha: 0.1),
                  FreezmeColors.surfaceAlt,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const FreezmeLogo(size: LogoSize.sm, showText: true),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: FreezmeColors.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.flash_on, color: FreezmeColors.secondary, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    flow.isPremium ? '∞' : '${flow.vibeCredits}',
                                    style: const TextStyle(
                                      color: FreezmeColors.secondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              onPressed: flow.openCircleDiscovery,
                              icon: const Icon(Icons.groups_rounded),
                              color: FreezmeColors.primary,
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              onPressed: flow.openDailyRecap,
                              icon: const Icon(Icons.trending_up),
                              color: FreezmeColors.primary,
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              onPressed: flow.openProfileSettings,
                              icon: const Icon(Icons.settings),
                              color: FreezmeColors.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your ${flow.dailyProfiles.length} vibes are ready 💫',
                          style: const TextStyle(
                            color: FreezmeColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (var i = 0; i < flow.dailyProfiles.length; i++)
                              Expanded(
                                child: Container(
                                  height: 4,
                                  margin: EdgeInsets.only(
                                      right: i == flow.dailyProfiles.length - 1
                                          ? 0
                                          : 8),
                                  decoration: BoxDecoration(
                                    color: i <= flow.poolIndex
                                        ? FreezmeColors.primary
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              profile.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const ColoredBox(
                                color: FreezmeColors.border,
                                child: Icon(Icons.person, size: 48),
                              ),
                            ),
                            if (profile.dna != null)
                              Positioned(
                                top: 20,
                                right: 20,
                                child: _CompatibilityDNACard(dna: profile.dna!),
                              ),
                            Positioned(
                              top: 20,
                              left: 20,
                              child: _AnimatedEntrance(
                                delay: const Duration(milliseconds: 300),
                                child: _buildNudgeComponent(flow, profile),
                              ),
                            ),
                            Positioned(
                              top: 60,
                              right: 20,
                              child: _AnimatedEntrance(
                                delay: const Duration(milliseconds: 400),
                                child: _buildArchetypeBadges(profile),
                              ),
                            ),
                            Positioned(
                              top: 110,
                              right: 20,
                              child: _AnimatedEntrance(
                                delay: const Duration(milliseconds: 500),
                                child: _buildVibeRadar(missionTheme),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black87,
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${profile.name}, ${profile.age}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      profile.distance,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      profile.bio,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton.outlined(
                              onPressed: flow.skipProfile,
                              icon: const Icon(Icons.close),
                              color: FreezmeColors.muted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: FreezmeColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(56),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: () =>
                                    _handleVibe(context, flow, profile),
                                icon: const Icon(Icons.favorite),
                                label: Text('Vibe with ${profile.name}'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton.outlined(
                              onPressed: () => _handleShowFreezeModal(context),
                              icon: const Icon(Icons.ac_unit),
                              color: FreezmeColors.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          remaining == 0
                              ? 'Last vibe for today'
                              : '$remaining ${remaining == 1 ? 'vibe' : 'vibes'} remaining today',
                          style: const TextStyle(
                            color: FreezmeColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (flow.vibeCredits < 2 && !flow.isPremium)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: FreezmeColors.secondary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.bolt, color: Colors.white, size: 16),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Running low on Vibez!',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                TextButton(
                                  onPressed: flow.openFreezmePlus,
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white24,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Text('Get More', style: TextStyle(color: Colors.white, fontSize: 11)),
                                ),
                              ],
                            ),
                          ),
                        TextButton(
                          onPressed: flow.openFreezmePlus,
                          child: const Text('Level up with Freezme+'),
                        ),
                      ],
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

  void _handleShowFreezeModal(BuildContext context) {
    showFreezeModal(context);
  }

  Widget _buildNudgeComponent(AppFlowController flow, VibeProfile profile) {
    final nudgeText = _getNudgeText(flow.selectedArchetype, profile);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white38),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.tips_and_updates, color: FreezmeColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nudgeText,
                  style: const TextStyle(
                    color: FreezmeColors.neutral,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArchetypeBadges(VibeProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: profile.archetypes.map((archetype) {
        final String emoji;
        switch (archetype) {
          case LifestyleArchetype.gym: emoji = '🏋️'; break;
          case LifestyleArchetype.brunch: emoji = '🥂'; break;
          case LifestyleArchetype.clubbing: emoji = '🎶'; break;
          case LifestyleArchetype.travel: emoji = '🎒'; break;
          case LifestyleArchetype.homebody: emoji = '🏠'; break;
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 18)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVibeRadar(MissionTheme theme) {
    return _AnimatedVibeRadar(color: theme.accentColor);
  }
}

class _AnimatedVibeRadar extends StatefulWidget {
  final Color color;
  const _AnimatedVibeRadar({required this.color});

  @override
  State<_AnimatedVibeRadar> createState() => _AnimatedVibeRadarState();
}

class _AnimatedVibeRadarState extends State<_AnimatedVibeRadar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _targets = [0.8, 0.6, 0.9, 0.7, 0.5];

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final currentValues = _targets
                  .map((t) => t * Curves.elasticOut.transform(_controller.value))
                  .toList();
              return CustomPaint(
                painter: VibeRadarPainter(
                  color: widget.color,
                  values: currentValues,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AnimatedEntrance extends StatelessWidget {
  final Widget child;
  final Duration delay;

  const _AnimatedEntrance({required this.child, required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
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

class _CompatibilityDNACard extends StatefulWidget {
  final CompatibilityDNA dna;

  const _CompatibilityDNACard({required this.dna});

  @override
  State<_CompatibilityDNACard> createState() => _CompatibilityDNACardState();
}

class _CompatibilityDNACardState extends State<_CompatibilityDNACard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        width: _isExpanded ? 240 : 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.biotech, color: Colors.purpleAccent, size: 20),
                if (_isExpanded) ...[
                  const SizedBox(width: 8),
                  const Text(
                    'Compatibility DNA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ] else ...[
                  const Spacer(),
                  Text(
                    '${widget.dna.overall}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 16),
              _DNARow(label: 'Lifestyle', value: widget.dna.lifestyle, color: Colors.blueAccent),
              const SizedBox(height: 8),
              _DNARow(label: 'Personality', value: widget.dna.personality, color: Colors.greenAccent),
              const SizedBox(height: 8),
              _DNARow(label: 'Values', value: widget.dna.values, color: Colors.orangeAccent),
              const SizedBox(height: 8),
              _DNARow(label: 'Communication', value: widget.dna.communication, color: Colors.pinkAccent),
              const SizedBox(height: 16),
              const Text('WHY YOU MATCH', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              const _MatchReason(text: "Shared lifestyle archetypes"),
              const _MatchReason(text: "High values alignment"),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Tap to collapse',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MatchReason extends StatelessWidget {
  final String text;
  const _MatchReason({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 12),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _DNARow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _DNARow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text('$value%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 3,
          ),
        ),
      ],
    );
  }
}

class VibeRadarPainter extends CustomPainter {
  final Color color;
  final List<double> values;

  VibeRadarPainter({required this.color, required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
        final angle = (i * 2 * math.pi / values.length) - (math.pi / 2);
        points.add(Offset(
            center.dx + radius * values[i] * math.cos(angle),
            center.dy + radius * values[i] * math.sin(angle)
        ));
    }

    final path = Path();
    path.addPolygon(points, true);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);

    // Draw background web
    final webPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke;
    
    for (var i = 1; i <= 3; i++) {
        canvas.drawCircle(center, radius * (i / 3), webPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
