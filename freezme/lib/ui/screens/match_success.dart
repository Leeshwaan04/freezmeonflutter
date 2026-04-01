import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../../models/blueprint.dart';
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
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
                          const _MatchAvatar(
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
                    const SizedBox(height: 24),
                    if (profile?.dna != null)
                      _StaggeredEntrance(
                        delayIndex: 3,
                        child: _CompatibilityExplainCard(dna: profile!.dna!),
                      ),
                    const SizedBox(height: 40),
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

// ─── Compatibility Explainability Card ────────────────────────────────────────
class _CompatibilityExplainCard extends StatelessWidget {
  const _CompatibilityExplainCard({required this.dna});

  final CompatibilityDNA dna;

  static const _labels = <String, String>{
    'personality': 'Personality match',
    'values': 'Shared values',
    'lifestyle': 'Lifestyle alignment',
    'communication': 'Communication style',
  };

  static const _sentences = <String, String>{
    'personality': 'You approach life with a similar mindset and energy.',
    'values': 'You both care deeply about the same things.',
    'lifestyle': 'Your day-to-day rhythms naturally align.',
    'communication': 'You connect through the same language of care.',
  };

  // Generate a two-sentence human-readable summary from the top two dimensions.
  String _buildSummary(List<MapEntry<String, int>> top) {
    if (top.isEmpty) return '';
    if (top.length == 1) return _sentences[top.first.key] ?? '';
    return '${_sentences[top[0].key] ?? ''} ${_sentences[top[1].key] ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final scored = <MapEntry<String, int>>[
      MapEntry('personality', dna.personality),
      MapEntry('values', dna.values),
      MapEntry('lifestyle', dna.lifestyle),
      MapEntry('communication', dna.communication),
    ]..sort((a, b) => b.value.compareTo(a.value));

    final topReasons = scored.where((e) => e.value >= 60).take(3).toList();
    if (topReasons.isEmpty) return const SizedBox.shrink();

    final summary = _buildSummary(topReasons);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why you match',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          if (dna.highlights != null && dna.highlights!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...dna.highlights!.map((h) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 12),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      h,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              summary,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...topReasons.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white70,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _labels[e.key] ?? e.key,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  _CompatBar(score: e.value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatBar extends StatelessWidget {
  const _CompatBar({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.25)),
            FractionallySizedBox(
              widthFactor: score / 100,
              child: Container(color: Colors.white),
            ),
          ],
        ),
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
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.grey.shade200),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
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
