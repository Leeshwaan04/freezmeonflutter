import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../../core/app_stage.dart';
import '../widgets/luxury_animations.dart';

class MatchSuccessPage extends StatefulWidget {
  const MatchSuccessPage({super.key});

  @override
  State<MatchSuccessPage> createState() => _MatchSuccessPageState();
}

class _MatchSuccessPageState extends State<MatchSuccessPage> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    final profile = flow.activeProfile;
    final missionTheme = MissionTheme.fromArchetype(flow.selectedArchetype);

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    missionTheme.accentColor,
                    FreezmeColors.primary,
                    FreezmeColors.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // Sparkle Layer
          const Positioned.fill(child: VibeSparkle(child: SizedBox.expand())),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _StaggeredEntrance(
                      delayIndex: 0,
                      child: Icon(Icons.favorite, color: Colors.white, size: 96),
                    ),
                    const SizedBox(height: 24),
                    _StaggeredEntrance(
                      delayIndex: 1,
                      child: Text(
                        'It\'s a Vibe! 💜',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StaggeredEntrance(
                      delayIndex: 2,
                      child: Text(
                        profile != null
                            ? 'You and ${profile.name} both felt it.'
                            : 'Your match is excited to chat',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 48),
                    _StaggeredEntrance(
                      delayIndex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _MatchAvatar(
                            imageUrl:
                                'https://images.unsplash.com/flagged/photo-1596479042555-9265a7fa7983?fit=crop&w=320',
                            label: 'You',
                          ),
                          const SizedBox(width: 24),
                          const Text('💜', style: TextStyle(fontSize: 48)),
                          const SizedBox(width: 24),
                          _MatchAvatar(
                            imageUrl: profile?.imageUrl ??
                                'https://images.unsplash.com/photo-1546961329-78bef0414d7c?fit=crop&w=320',
                            label: profile?.name ?? 'Match',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 64),
                    _StaggeredEntrance(
                      delayIndex: 4,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: FreezmeColors.primary,
                          minimumSize: const Size.fromHeight(64),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 8,
                        ),
                        onPressed: flow.finishMatchSuccessToChat,
                        icon: const Icon(Icons.message_rounded),
                        label: const Text(
                          'Start the Conversation',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _StaggeredEntrance(
                      delayIndex: 5,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                        ),
                        onPressed: flow.finishMatchSuccessToPool,
                        child: const Text(
                          'Maybe Later',
                          style: TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
            child: Transform.scale(
              scale: 0.9 + (0.1 * value),
              child: child,
            ),
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(top: delayIndex * 4.0), // Subtle spacing/stagger
        child: child,
      ),
    );
  }
}

class _MatchAvatar extends StatelessWidget {
  const _MatchAvatar({required this.imageUrl, required this.label});

  final String imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 100,
          width: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(imageUrl, fit: BoxFit.cover),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
