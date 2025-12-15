import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../main.dart'; // For AppFlowScope
import '../design_system.dart';
import '../components/freezme_logo.dart';
import '../components/premium_components.dart';

class ProfilePreviewPage extends StatelessWidget {
  const ProfilePreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final uploadedPhotos = flow.photoSlots
        .where((p) => p.status == PhotoSlotStatus.uploaded && p.imageUrl != null)
        .map((p) => p.imageUrl!)
        .toList();
    final primaryPhoto = uploadedPhotos.isNotEmpty
        ? uploadedPhotos.first
        : 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080';
    final completion = ((uploadedPhotos.length / flow.photoSlots.length) * 100)
        .clamp(0, 100)
        .round();

    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: FreezmeDesignSystem.textPrimary),
          onPressed: flow.pop,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(FreezmeDesignSystem.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FreezmeLogo(size: LogoSize.md, showText: true),
                const SizedBox(height: 20),
                Text(
                  'Your Vibe Profile',
                  style: FreezmeDesignSystem.h2.copyWith(color: FreezmeDesignSystem.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  uploadedPhotos.isEmpty
                      ? 'Add a few photos to complete your vibe 💜'
                      : 'Looking good! $completion% complete',
                  style: FreezmeDesignSystem.caption,
                ),
                const SizedBox(height: 24),
                
                // Profile Card
                Container(
                  decoration: FreezmeDesignSystem.cardDecoration,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final dpr = MediaQuery.of(context).devicePixelRatio;
                          final memCacheWidth = (constraints.maxWidth * dpr).round();
                          return SizedBox(
                            height: 320,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: primaryPhoto,
                                  fit: BoxFit.cover,
                                  memCacheWidth: memCacheWidth,
                                  placeholder: (context, url) => const ColoredBox(color: FreezmeDesignSystem.surfaceAlt),
                                  errorWidget: (context, url, error) => const ColoredBox(
                                    color: FreezmeDesignSystem.surfaceAlt,
                                    child: Icon(Icons.person, size: 48, color: FreezmeDesignSystem.textSecondary),
                                  ),
                                ),
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [Colors.black54, Colors.transparent],
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  left: 24,
                                  right: 24,
                                  bottom: 24,
                                  child: Text(
                                    'Your vibe',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('About Me', style: FreezmeDesignSystem.h3),
                            const SizedBox(height: 8),
                            const Text(
                              'Finish your bio and preferences to help matches get to know you. You can edit photos, interests, and distance in Settings.',
                              style: FreezmeDesignSystem.body,
                            ),
                            const SizedBox(height: 24),
                            
                            if (uploadedPhotos.isNotEmpty) ...[
                              const Text('Photos', style: FreezmeDesignSystem.h3),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: uploadedPhotos.map(
                                  (url) => ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: CachedNetworkImage(
                                      imageUrl: url,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ).toList(),
                              ),
                              const SizedBox(height: 24),
                            ],
                            
                            Row(
                              children: [
                                Expanded(
                                  child: PremiumButton(
                                    label: 'Edit Photos',
                                    icon: Icons.photo_camera_back,
                                    variant: ButtonVariant.filled,
                                    onPressed: () => flow.startOnboarding(), // reuse uploader
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: PremiumButton(
                                    label: 'Edit Details',
                                    variant: ButtonVariant.outlined,
                                    onPressed: () => flow.pushIfMissing(AppStage.editProfile),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            const Text('Interests', style: FreezmeDesignSystem.h3),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: const [
                                PremiumChip(label: 'Music'),
                                PremiumChip(label: 'Travel'),
                                PremiumChip(label: 'Art'),
                                PremiumChip(label: 'Yoga'),
                                PremiumChip(label: 'Coffee'),
                                PremiumChip(label: 'Photography'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
