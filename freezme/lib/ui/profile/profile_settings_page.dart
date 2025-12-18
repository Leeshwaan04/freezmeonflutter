import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../main.dart'; // For AppFlowScope, AppStage
import '../design_system.dart';
import '../components/premium_components.dart';
import '../components/freezme_logo.dart';
import '../components/aurora_background.dart';
import '../settings/preferences_page.dart';
import '../settings/settings_pages.dart';
import '../settings/freezme_plus_page.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  bool _signingOut = false;

  Future<void> _confirmSignOut(AppFlowController flow) async {
    if (_signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'We’ll pause your presence and take you back to the welcome screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _signingOut = true);
    try {
      await flow.signOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Widget _fallbackAvatar(String initials) {
    return Container(
      height: 80,
      width: 80,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: FreezmeGradients.primary,
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    final completion = flow.completionPercent;
    final vibesLeft = flow.remainingProfiles;
    final matchesCount = flow.matchesCount;
    final profileName = flow.profileName ?? 'Freezme member';
    final profileEmail = flow.profileEmail ?? 'Add your email';
    final photoUrl = flow.profilePhotoUrl;
    final avatar = UserAvatar(
      imageUrl: photoUrl,
      size: 80,
      isPremium: flow.isPremium,
    );

    final menuItems = [
     (
        icon: Icons.person_outline,
        label: 'Edit Profile',
        description: 'Update your photos and bio',
        action: () => flow.pushIfMissing(AppStage.editProfile),
      ),
      (
        icon: Icons.tune,
        label: 'Preferences',
        description: 'Age range, distance, interests',
        action: () => Navigator.of(context).push(SmoothPageRoute(page: const PreferencesPage())),
      ),
      (
        icon: Icons.star_outline,
        label: 'Freezme+',
        description: 'See who likes you & more',
        action: () => Navigator.of(context).push(SmoothPageRoute(page: const FreezmePlusPage())),
      ),
      (
        icon: Icons.security,
        label: 'Safety & Privacy',
        description: 'Manage your data and safety',
        action: () => Navigator.of(context).push(SmoothPageRoute(page: const SafetyPrivacyPage())),
      ),
      (
        icon: Icons.help_outline,
        label: 'Help & Support',
        description: 'FAQ and contact us',
        action: () => Navigator.of(context).push(SmoothPageRoute(page: const HelpSupportPage())),
      ),
    ];

    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      body: AuroraBackground(
        isPremium: flow.isPremium,
        child: SafeArea(
          child: Column(
            children: [
              // Header Gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FreezmeLogo(
                      size: LogoSize.sm,
                      variant: LogoVariant.primary,
                      showText: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton.filled(
                          onPressed: flow.pop,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: FreezmeDesignSystem.primary,
                            side: const BorderSide(color: FreezmeDesignSystem.border),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Profile & Settings',
                          style: TextStyle(
                            color: FreezmeDesignSystem.primary,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Profile Card
                      PremiumCard(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          children: [
                            avatar,
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profileName,
                                    style: FreezmeDesignSystem.h3,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    profileEmail,
                                    style: FreezmeDesignSystem.caption,
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: FreezmeDesignSystem.pillDecoration,
                                    child: Text(
                                      '${completion.toInt()}% Complete',
                                      style: FreezmeDesignSystem.smallMedium.copyWith(color: FreezmeDesignSystem.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _StatPill(
                            label: 'Vibes left',
                            value: vibesLeft.toString(),
                            icon: Icons.favorite_border,
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: _StatPill(
                            label: 'Matches',
                            value: matchesCount.toString(),
                            icon: Icons.chat_bubble_outline,
                          )),
                        ],
                      ),
                      
                      // Profile Completion Banner - show when profile is not complete
                      if (!flow.isProfileComplete) ...[
                        const SizedBox(height: 16),
                        _buildProfileCompletionBanner(flow, completion.toDouble()),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Menu Items
                      PremiumCard(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            for (var i = 0; i < menuItems.length; i++) ...[
                              if (i > 0) const Divider(indent: 60),
                              ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: FreezmeDesignSystem.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(menuItems[i].icon, color: FreezmeDesignSystem.primary),
                                ),
                                title: Text(menuItems[i].label, style: FreezmeDesignSystem.bodyMedium),
                                subtitle: Text(menuItems[i].description, style: FreezmeDesignSystem.caption),
                                onTap: menuItems[i].action,
                                trailing: const Icon(Icons.chevron_right, color: FreezmeDesignSystem.textTertiary),
                              ),
                            ]
                          ],
                        ),
                      ),
                      
                       const SizedBox(height: 24),
                       
                       // Sign Out
                       PremiumButton(
                         label: 'Sign Out',
                         variant: ButtonVariant.outlined,
                         onPressed: () => _confirmSignOut(flow),
                         fullWidth: true,
                         loading: _signingOut,
                       ),
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

  Widget _buildProfileCompletionBanner(AppFlowController flow, double completion) {
    return GestureDetector(
      onTap: () => flow.replaceStack(<AppStage>[AppStage.profileCompletion]),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: FreezmeGradients.header,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: FreezmeDesignSystem.primary.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Rocket Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.rocket_launch_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Complete Your Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Progress indicator
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: completion / 100,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${completion.toInt()}%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unlock Tonight Mode to match nearby',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.8),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatPill({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration:  BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FreezmeDesignSystem.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: FreezmeDesignSystem.primary, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: FreezmeDesignSystem.h3),
              Text(label, style: FreezmeDesignSystem.small),
            ],
          ),
        ],
      ),
    );
  }
}
