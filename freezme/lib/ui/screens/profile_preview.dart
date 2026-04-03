import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../../core/app_stage.dart';
import '../../models/photo_slot.dart';
import '../profile/edit_profile_page.dart';
import '../components/premium_components.dart';

class ProfilePreviewPage extends StatelessWidget {
  const ProfilePreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);

    final name = flow.profileName ?? 'You';
    final age = flow.profileAge;
    final nameAgeLabel = age != null && age > 0 ? '$name, $age' : name;

    final bio = flow.profileBio;
    final interests = flow.profileInterests;

    // Best available photo: first uploaded slot, then server profilePhotoUrl
    final uploadedUrl = flow.photoSlots
        .where((s) => s.status == PhotoSlotStatus.uploaded && s.imageUrl != null)
        .map((s) => s.imageUrl!)
        .firstOrNull;
    final photoUrl = uploadedUrl ?? flow.profilePhotoUrl;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button row
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, size: 28),
                  color: FreezmeColors.neutral,
                  onPressed: flow.pop,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile photo
                      ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: photoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: photoUrl,
                                height: 480,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                memCacheWidth: 1080,
                                placeholder: (context, url) =>
                                    Container(color: Colors.grey.shade200),
                                errorWidget: (context, url, error) =>
                                    _PhotoPlaceholder(name: name),
                              )
                            : SizedBox(
                                height: 480,
                                width: double.infinity,
                                child: _PhotoPlaceholder(name: name),
                              ),
                      ),
                      const SizedBox(height: 24),

                      // Name / age + edit button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nameAgeLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: FreezmeColors.neutral,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  flow.profileEmail ?? 'Freezme member',
                                  style: const TextStyle(
                                      color: FreezmeColors.muted),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(SmoothPageRoute(page: const EditProfilePage())),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: FreezmeGradients.primary,
                              ),
                              child: const Icon(Icons.edit,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // About Me
                      const Text(
                        'About Me',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: FreezmeColors.neutral,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bio?.isNotEmpty == true
                            ? bio!
                            : 'Add a bio to tell people about yourself.',
                        style: TextStyle(
                          color: bio?.isNotEmpty == true
                              ? FreezmeColors.neutral
                              : FreezmeColors.muted,
                          height: 1.5,
                        ),
                      ),

                      // Interests
                      if (interests.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Interests',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: FreezmeColors.neutral,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final label in interests)
                              _PreviewChip(label: label),
                          ],
                        ),
                      ],

                      // Photo grid (additional uploaded slots)
                      () {
                        final extraPhotos = flow.photoSlots
                            .where((s) =>
                                s.status == PhotoSlotStatus.uploaded &&
                                s.imageUrl != null &&
                                s.imageUrl != uploadedUrl)
                            .toList();
                        if (extraPhotos.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),
                            const Text(
                              'Photos',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: FreezmeColors.neutral,
                              ),
                            ),
                            const SizedBox(height: 12),
                            GridView.count(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                for (final slot in extraPhotos)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: slot.imageUrl!,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 360,
                                      placeholder: (context, url) =>
                                          Container(
                                              color: Colors.grey.shade200),
                                      errorWidget: (context, url, error) =>
                                          const Icon(Icons.error),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );
                      }(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FreezmeColors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, size: 80, color: FreezmeColors.muted),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                  color: FreezmeColors.muted, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FreezmeColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: FreezmeColors.neutral,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
