import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/vibe_profile.dart';
import '../../main.dart'; // For AppFlowScope
import '../design_system.dart';
import '../components/premium_components.dart';
import '../components/safety_actions_sheet.dart';

class ProfileDetailPage extends StatelessWidget {
  final VibeProfile profile;

  const ProfileDetailPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);

    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: FreezmeDesignSystem.background,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: profile.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const ColoredBox(color: FreezmeDesignSystem.surfaceAlt),
                    errorWidget: (context, url, error) => const ColoredBox(
                      color: FreezmeDesignSystem.surfaceAlt,
                      child: Icon(Icons.person, size: 64, color: FreezmeDesignSystem.textTertiary),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black54,
                        ],
                        stops: [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                  child: IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.black),
                    onPressed: () => SafetyActionsSheet.show(
                      context,
                      targetUid: profile.uid,
                      targetName: profile.name,
                      context_: 'profile',
                    ),
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(FreezmeDesignSystem.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${profile.name}, ${profile.age}',
                              style: FreezmeDesignSystem.h1,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 16, color: FreezmeDesignSystem.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  profile.distance,
                                  style: FreezmeDesignSystem.body.copyWith(color: FreezmeDesignSystem.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: FreezmeDesignSystem.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${profile.compatibility.round()}% Match',
                          style: const TextStyle(
                            color: FreezmeDesignSystem.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    children: [
                      Expanded(
                        child: PremiumButton(
                          label: 'Pass',
                          icon: Icons.close,
                          variant: ButtonVariant.outlined,
                          onPressed: () {
                             flow.repository.skipProfile(profile.uid);
                             Navigator.of(context).pop();
                             PremiumSnackBar.show(context, 'Skipped', type: SnackBarType.info);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: PremiumButton(
                          label: 'Like',
                          icon: Icons.favorite,
                          variant: ButtonVariant.filled,
                          onPressed: () {
                             flow.repository.likeProfile(profile.uid);
                             Navigator.of(context).pop();
                             PremiumSnackBar.show(context, 'You liked ${profile.name}!', type: SnackBarType.success);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Bio
                  const Text('About', style: FreezmeDesignSystem.h3),
                  const SizedBox(height: 8),
                  Text(
                    profile.bio.isNotEmpty ? profile.bio : 'No bio yet.',
                    style: FreezmeDesignSystem.body,
                  ),
                  const SizedBox(height: 24),

                  // Energy + Presence row
                  if (profile.energyType != null || profile.presenceLabel != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (profile.energyType != null)
                          _InfoChip(
                            emoji: profile.energyType!.emoji,
                            label: profile.energyType!.label,
                          ),
                        if (profile.energyType != null && profile.presenceLabel != null)
                          const SizedBox(width: 8),
                        if (profile.presenceLabel != null)
                          _InfoChip(
                            emoji: profile.presenceLabel!.emoji,
                            label: profile.presenceLabel!.label,
                          ),
                      ],
                    ),
                    if (profile.energyType != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          profile.energyType!.description,
                          style: FreezmeDesignSystem.body.copyWith(
                              color: FreezmeDesignSystem.textSecondary,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],

                  // Shared interests
                  if (profile.sharedInterests.isNotEmpty) ...[
                    const Text('In common', style: FreezmeDesignSystem.h3),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: profile.sharedInterests
                          .map((i) => PremiumChip(label: i, selected: true))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Interests
                  if (profile.interests.isNotEmpty) ...[
                    const Text('Interests', style: FreezmeDesignSystem.h3),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: profile.interests.map((i) => PremiumChip(label: i)).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // More Photos
                  if (profile.photoUrls.isNotEmpty) ...[
                    const Text('Photos', style: FreezmeDesignSystem.h3),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: profile.photoUrls.length,
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: profile.photoUrls[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const ColoredBox(color: FreezmeDesignSystem.surfaceAlt),
                          ),
                        );
                      },
                    ),
                  ],
                  
                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.emoji, required this.label});
  final String emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FreezmeDesignSystem.primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FreezmeDesignSystem.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: FreezmeDesignSystem.primary)),
        ],
      ),
    );
  }
}
