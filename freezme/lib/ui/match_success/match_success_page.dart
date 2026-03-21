import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../main.dart';
import '../design_system.dart';
import '../shared/bottom_nav_bar.dart';

class MatchSuccessPage extends StatelessWidget {
  const MatchSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    final loading = flow.pathsLoading;
    final nearby = flow.nearbyPaths;

    if (loading && nearby.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: FreezmeGradients.backgroundSoft,
          ),
          child: const SafeArea(
            child: Center(
              child: CircularProgressIndicator(
                color: FreezmeDesignSystem.primary,
              ),
            ),
          ),
        ),
        bottomNavigationBar: FreezmeBottomNavBar(
          currentIndex: 3,
          onTap: flow.openTab,
        ),
      );
    }
    final profile = flow.activeProfile;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              FreezmeDesignSystem.primary,
              FreezmeDesignSystem.secondary,
              FreezmeDesignSystem.accent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 96),
                  const SizedBox(height: 24),
                  Text(
                    'It\'s a Vibe! 💜',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile != null
                        ? 'You and ${profile.name} both felt the connection'
                        : 'Your match is excited to chat',
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
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
                        imageUrl:
                            profile?.imageUrl ??
                            'https://images.unsplash.com/photo-1546961329-78bef0414d7c?fit=crop&w=320',
                        label: profile?.name ?? 'Match',
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: FreezmeDesignSystem.primary,
                      minimumSize: const Size.fromHeight(56),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: flow.finishMatchSuccessToChat,
                    icon: const Icon(Icons.message_outlined),
                    label: const Text('Start Chat'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      minimumSize: const Size.fromHeight(56),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: flow.finishMatchSuccessToPool,
                    child: const Text('Maybe Later'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Good vibes only 💫',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
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
          height: 96,
          width: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.white24),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
