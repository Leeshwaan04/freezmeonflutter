import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/vibe_profile.dart';
import '../../main.dart';
import '../design_system.dart';
import '../components/aurora_background.dart';
import '../components/skeleton_loaders.dart';

class LikesPage extends StatefulWidget {
  const LikesPage({super.key});

  @override
  State<LikesPage> createState() => _LikesPageState();
}

class _LikesPageState extends State<LikesPage> {
  bool _isLoading = true;
  List<VibeProfile> _likes = [];
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadLikes();
  }

  Future<void> _loadLikes() async {
    final flow = AppFlowScope.of(context, listen: false);
    setState(() {
      _isLoading = true;
      _isPremium = flow.isPremium;
    });
    try {
      final likes = await flow.repository.fetchLikes();
      if (mounted) {
        setState(() {
          _likes = likes;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    // Listen to premium status changes dynamically
    if (flow.isPremium != _isPremium) {
      _isPremium = flow.isPremium;
    }

    return Scaffold(
      // Transparent so the shared AuroraBackground shows through — keeps the
      // backdrop consistent with Tonight/Chats/Paths/Blinds/Profile (Likes was
      // the only main tab on a flat white background).
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Likes', style: FreezmeDesignSystem.h1),
        centerTitle: false, // iOS defaults to centered; left-align to match other tabs
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AuroraBackground(
        isPremium: _isPremium,
        child: _isLoading
            ? const LikesGridSkeleton()
            : _likes.isEmpty
                ? _buildEmptyState()
                : _buildGrid(flow),
      ),
    );
  }

  Widget _buildEmptyState() {
    // Warm gradient-orb empty state with a CTA — matches the Chats empty-state
    // language (was a cold grey outline heart with no action).
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FreezmeDesignSystem.spaceLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7C3AED), Color(0xFFDB2777)], // purple → pink
                ),
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('Your likes will land here', style: FreezmeDesignSystem.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'When someone likes you, they show up here — like them back to match instantly.',
              textAlign: TextAlign.center,
              style: FreezmeDesignSystem.body.copyWith(color: FreezmeDesignSystem.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => AppFlowScope.of(context, listen: false).openTab(0),
              icon: const Icon(Icons.explore_outlined, size: 18),
              style: FilledButton.styleFrom(
                backgroundColor: FreezmeDesignSystem.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusLg),
                ),
              ),
              label: const Text('Explore tonight'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(AppFlowController flow) {
    final n = _likes.length;
    final plural = n == 1 ? 'person likes' : 'people like';
    final countLabel = _isPremium
        ? '$n $plural you'
        : '$n $plural you — tap any to reveal';
    return RefreshIndicator(
      onRefresh: _loadLikes,
      color: FreezmeDesignSystem.primary,
      child: CustomScrollView(
        slivers: [
          // Social-proof count — drives the upgrade for non-premium users.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                countLabel,
                style: FreezmeDesignSystem.body.copyWith(
                  color: FreezmeDesignSystem.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final profile = _likes[index];
                  return GestureDetector(
                    onTap: () {
                      if (_isPremium) {
                        flow.activeProfile = profile;
                        flow.push(AppStage.profilePreview);
                      } else {
                        flow.push(AppStage.freezmePlus);
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: profile.imageUrl.isNotEmpty ? profile.imageUrl : (profile.photoUrls.isNotEmpty ? profile.photoUrls.first : ''),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const SkeletonLoader(width: double.infinity, height: double.infinity),
                            errorWidget: (context, url, error) => const _LikePhotoFallback(),
                          ),
                          if (!_isPremium) ...[
                            BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(color: Colors.black.withValues(alpha: 0.12)),
                            ),
                            const Center(
                              child: Icon(Icons.lock_outline, color: Colors.white, size: 48),
                            ),
                          ],
                          if (_isPremium)
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                                  ),
                                ),
                                child: Text(
                                  profile.name.split(' ').first,
                                  style: FreezmeDesignSystem.h3.copyWith(color: Colors.white, fontSize: 16),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: _likes.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Branded fallback for a like card with a missing photo — dark purple gradient
/// + glyph instead of a flat grey block (the grid sits on dark imagery).
class _LikePhotoFallback extends StatelessWidget {
  const _LikePhotoFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4D2C91), Color(0xFF2E1A47)],
        ),
      ),
      child: Center(
        child: Icon(Icons.person_rounded, color: Colors.white24, size: 48),
      ),
    );
  }
}
