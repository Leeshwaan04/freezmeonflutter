import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import 'package:freezme/core/app_stage.dart';

class VideoDatePage extends StatefulWidget {
  const VideoDatePage({super.key});

  @override
  State<VideoDatePage> createState() => _VideoDatePageState();
}

class _VideoDatePageState extends State<VideoDatePage> with SingleTickerProviderStateMixin {
  static const int _totalSeconds = 1200;

  late Timer _timer;
  int _timeRemaining = _totalSeconds;
  bool _isMuted = false;
  String? _reaction;
  Timer? _reactionTimer;
  int _promptIndex = 0;

  final Map<LifestyleArchetype, List<String>> _missionPrompts = {
    LifestyleArchetype.gym: [
      "What's your current PR goal?",
      "Early bird or night owl at the gym?",
      "Best post-workout meal in the city?",
    ],
    LifestyleArchetype.brunch: [
      "Avocado toast or Eggs Benedict?",
      "Top 3 brunch spots we MUST visit?",
      "Mimosa or specialized coffee?",
    ],
    LifestyleArchetype.clubbing: [
      "Techno or House music?",
      "Favourite spot for a late-night vibe?",
      "Worst pick-up line you've heard at a club?",
    ],
    LifestyleArchetype.travel: [
      "Next dream destination on your list?",
      "Beach relaxation or mountain adventure?",
      "One thing you never travel without?",
    ],
    LifestyleArchetype.homebody: [
      "Ultimate comfort movie or series?",
      "Best pizza place for a night in?",
      "Are you a board game or video game person?",
    ],
  };

  List<String> get _currentPrompts {
    final archetype = AppFlowScope.of(context, listen: false).selectedArchetype ?? LifestyleArchetype.brunch;
    return _missionPrompts[archetype] ?? _missionPrompts[LifestyleArchetype.brunch]!;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timeRemaining == 0) {
        timer.cancel();
        _showRatingModal();
      } else {
        setState(() => _timeRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _reactionTimer?.cancel();
    super.dispose();
  }

  void _handleReaction(String emoji) {
    _reactionTimer?.cancel();
    setState(() => _reaction = emoji);
    _reactionTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _reaction = null);
    });
  }

  void _showRatingModal() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              const Text(
                'How was the vibe? ✨',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: FreezmeColors.neutral, letterSpacing: -0.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your feedback helps our matching engine\nfind even better connections for you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: FreezmeColors.muted, height: 1.4),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRatingOption('❄️', 'Cold'),
                  _buildRatingOption('☁️', 'Neutral'),
                  _buildRatingOption('🔥', 'Vibing'),
                ],
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  AppFlowScope.of(context, listen: false).completeVideoDate();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: FreezmeColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                ),
                child: const Text('Complete Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingOption(String emoji, String label) {
    return Column(
      children: [
        Container(
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            color: FreezmeColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: FreezmeColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 36)),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: FreezmeColors.neutral),
        ),
      ],
    );
  }

  String get _formattedTime {
    final minutes = _timeRemaining ~/ 60;
    final seconds = _timeRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final profile = flow.activeProfile;

    return Scaffold(
      body: Container(
        color: Colors.black, // Dark background for video
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // Partner Feed
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.network(
                    profile?.imageUrl ?? 'https://images.unsplash.com/photo-1546961329-78bef0414d7c?fit=crop&w=1080',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // HUD Overlay
              Column(
                children: [
                  // Top Info Bar
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _HUDGlassBox(
                          child: Row(
                            children: [
                              const CircleAvatar(radius: 4, backgroundColor: Colors.red),
                              const SizedBox(width: 8),
                              Text(
                                profile != null ? '${profile.name}, ${profile.age}' : 'Match',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        _HUDGlassBox(
                          child: Text(
                            _formattedTime,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Self View (Floating PIP)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        height: 180,
                        width: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20)],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.network(
                          'https://images.unsplash.com/flagged/photo-1596479042555-9265a7fa7983?fit=crop&w=1080',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  // Bottom Controls Area
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Vibe Prompt
                        _StaggeredEntrance(
                          delayIndex: 0,
                          child: _HUDGlassBox(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _currentPrompts[_promptIndex],
                                    style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                                  onPressed: () => setState(() => _promptIndex = (_promptIndex + 1) % _currentPrompts.length),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Bar
                        _StaggeredEntrance(
                          delayIndex: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ControlButton(
                                icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                                color: _isMuted ? Colors.redAccent : Colors.white12,
                                onPressed: () => setState(() => _isMuted = !_isMuted),
                              ),
                              const SizedBox(width: 20),
                              _ControlButton(
                                icon: Icons.call_end_rounded,
                                color: Colors.red,
                                iconSize: 32,
                                size: 80,
                                onPressed: () {
                                  _timer.cancel();
                                  _showRatingModal();
                                },
                              ),
                              const SizedBox(width: 20),
                              _ControlButton(
                                icon: Icons.videocam_rounded,
                                color: Colors.white12,
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Reactions
                        _StaggeredEntrance(
                          delayIndex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final emoji in ['❤️', '😂', '🙌', '🔥'])
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: _ReactionButton(emoji: emoji, onTap: () => _handleReaction(emoji)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Float Reaction Animation
              if (_reaction != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _FloatingReactionEffect(emoji: _reaction!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HUDGlassBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _HUDGlassBox({required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8)});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.color,
    this.size = 60,
    this.iconSize = 24,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: color != Colors.white12
              ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))]
              : null,
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _ReactionButton({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _HUDGlassBox(
        padding: const EdgeInsets.all(12),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }
}

class _FloatingReactionEffect extends StatelessWidget {
  final String emoji;
  const _FloatingReactionEffect({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 1),
      builder: (context, value, child) {
        return Stack(
          children: [
            Positioned(
              bottom: 200 + (300 * value),
              left: 50 + (math.sin(value * math.pi * 4) * 40),
              right: 50 - (math.sin(value * math.pi * 4) * 40),
              child: Opacity(
                opacity: 1 - value,
                child: Center(child: Text(emoji, style: const TextStyle(fontSize: 64))),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StaggeredEntrance extends StatelessWidget {
  final int delayIndex;
  final Widget child;

  const _StaggeredEntrance({required this.delayIndex, required this.child});

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
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
