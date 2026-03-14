import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../../models/profile.dart';
import '../widgets/freezme_logo.dart';
import '../widgets/freeze_modal.dart';
import '../../core/app_stage.dart';

class DailyVibePoolPage extends StatefulWidget {
  const DailyVibePoolPage({super.key});

  @override
  State<DailyVibePoolPage> createState() => _DailyVibePoolPageState();
}

class _DailyVibePoolPageState extends State<DailyVibePoolPage> {
  static const List<String> _timeSlots = <String>[
    'Today 7:00 PM',
    'Today 8:00 PM',
    'Tomorrow 6:00 PM',
    'Tomorrow 7:00 PM',
    'Tomorrow 8:00 PM',
  ];

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

  Future<String?> _showInviteDialog(BuildContext context) async {
    String? selected = _timeSlots.first;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Invite for a Vibe Date?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: FreezmeColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Choose a time for your 20-minute video date:',
                      style: TextStyle(
                        color: FreezmeColors.muted,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final slot in _timeSlots)
                          ChoiceChip(
                            label: Text(slot),
                            selected: selected == slot,
                            onSelected: (_) => setStateDialog(() {
                              selected = slot;
                            }),
                            selectedColor: FreezmeColors.primary,
                            labelStyle: TextStyle(
                              color: selected == slot
                                  ? Colors.white
                                  : FreezmeColors.neutral,
                            ),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: selected == slot
                                    ? FreezmeColors.primary
                                    : FreezmeColors.border,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: FreezmeColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(selected),
                      child: const Text('Confirm Vibe'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getNudgeText(LifestyleArchetype? userMission, VibeProfile profile) {
    if (userMission == null) return "Want to explore some vibes? ✨";

    final hasOverlap = profile.archetypes.contains(userMission);

    switch (userMission) {
      case LifestyleArchetype.gym:
        return hasOverlap
            ? "Looking for a PR partner or a tennis rival? Arjun is ready! 🎾"
            : "Arjun is more into ${profile.archetypes.first.name} vibes, but maybe a gym break? 🥦";
      case LifestyleArchetype.brunch:
        return hasOverlap
            ? "Sarah knows the best avocado toast in town. Sunday brunch? 🥂"
            : "Sarah is a clubbing pro, but she might enjoy a quiet coffee ☕";
      case LifestyleArchetype.clubbing:
        return hasOverlap
            ? "Searching for someone who knows the best guestlists? Dance? 🎶"
            : "A bit more 'Homey' than 'Clubby', but worth the vibe check! ✨";
      case LifestyleArchetype.travel:
        return hasOverlap
            ? "Adventure partner found! Weekend trek or road trip? 🎒"
            : "Not a traveler, but deep talks are guaranteed 🏠";
      case LifestyleArchetype.homebody:
        return hasOverlap
            ? "Cozy night and deep talks. Perfect match for a slow weekend 🏠"
            : "A bit higher energy than home, but opposites attract! ⚡";
      default:
        return "You both have amazing vibes! Match to see more 💫";
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
                            Positioned(
                              top: 20,
                              right: 20,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      FreezmeColors.primary,
                                      FreezmeColors.secondary,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${profile.compatibility}% Match',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
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
        String emoji;
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
