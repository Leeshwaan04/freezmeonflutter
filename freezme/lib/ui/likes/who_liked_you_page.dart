import 'dart:ui';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../data/freezme_repository.dart';
import '../../models/vibe_profile.dart';
import '../design_system.dart';
import '../shared/safe_image.dart';
import '../shared/state_views.dart';

/// "Who Liked You" — premium users see full profiles; free users see blurred
/// cards + a count and an upsell to unlock. Wired to GET /matching/liked-by.
class WhoLikedYouPage extends StatefulWidget {
  const WhoLikedYouPage({super.key});

  @override
  State<WhoLikedYouPage> createState() => _WhoLikedYouPageState();
}

class _WhoLikedYouPageState extends State<WhoLikedYouPage> {
  bool _loading = true;
  bool _error = false;
  LikedByResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final flow = AppFlowScope.of(context, listen: false);
      final res = await flow.repository.fetchLikedBy();
      if (mounted) setState(() { _result = res; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      appBar: AppBar(
        title: const Text('Who Liked You'),
        backgroundColor: FreezmeDesignSystem.background,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? ErrorView(message: 'Could not load your likes', onRetry: _load)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final result = _result!;
    if (result.count == 0) {
      return const EmptyView(
        title: 'No likes yet',
        subtitle: "When someone likes you, they'll show up here.",
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: result.profiles.length,
        itemBuilder: (context, i) => _LikeCard(
          profile: result.profiles[i],
          blurred: !result.isPremium,
          onUnlock: result.isPremium ? null : _goPremium,
        ),
      ),
    );
  }

  void _goPremium() {
    final flow = AppFlowScope.of(context, listen: false);
    Navigator.of(context).maybePop();
    flow.openFreezmePlus();
  }
}

class _LikeCard extends StatelessWidget {
  const _LikeCard({required this.profile, required this.blurred, this.onUnlock});

  final VibeProfile profile;
  final bool blurred;
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusLg),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: safeImageProvider(profile.imageUrl),
            fit: BoxFit.cover,
          ),
          if (blurred)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.black.withValues(alpha: 0.25)),
            ),
          // Gradient + label
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
              child: Text(
                blurred ? 'Someone, ${profile.age}' : '${profile.name}, ${profile.age}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (blurred)
            Center(
              child: GestureDetector(
                onTap: onUnlock,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: FreezmeDesignSystem.primary),
                      SizedBox(width: 6),
                      Text('Unlock', style: TextStyle(color: FreezmeDesignSystem.primary, fontWeight: FontWeight.bold)),
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
