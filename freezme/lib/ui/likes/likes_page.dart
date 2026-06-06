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
        title: const Text('Likes You', style: FreezmeDesignSystem.h3),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, size: 64, color: FreezmeDesignSystem.textTertiary),
          const SizedBox(height: 16),
          const Text('No likes yet', style: FreezmeDesignSystem.h2),
          const SizedBox(height: 8),
          Text(
            'When someone likes your profile,\nthey will appear here.',
            textAlign: TextAlign.center,
            style: FreezmeDesignSystem.body.copyWith(color: FreezmeDesignSystem.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(AppFlowController flow) {
    return RefreshIndicator(
      onRefresh: _loadLikes,
      color: FreezmeDesignSystem.primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: _likes.length,
        itemBuilder: (context, index) {
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
                    errorWidget: (context, url, error) => Container(color: Colors.grey.shade800),
                  ),
                  if (!_isPremium) ...[
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(color: Colors.black.withValues(alpha: 0.2)),
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
      ),
    );
  }
}
