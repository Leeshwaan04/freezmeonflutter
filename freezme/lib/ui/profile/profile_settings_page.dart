import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../main.dart'; // For AppFlowScope, AppStage
import '../design_system.dart';
import '../components/premium_components.dart';
import '../components/freezme_logo.dart';
import '../components/aurora_background.dart';
import '../settings/preferences_page.dart';
import '../settings/settings_pages.dart';
import '../settings/notification_prefs_page.dart';
import 'edit_profile_page.dart';


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

  bool _deletingAccount = false;

  Future<void> _confirmDeleteAccount(AppFlowController flow) async {
    if (_deletingAccount) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This will permanently delete your profile, matches, and all data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deletingAccount = true);
    try {
      await ApiClient.instance.dio.delete<Map<String, dynamic>>('/users/me');
      await flow.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
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
    // Derive initials from profile name so we never show '?'
    final nameInitials = profileName.isNotEmpty
        ? profileName.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join()
        : 'ME';
    final avatar = UserAvatar(
      imageUrl: photoUrl,
      initials: nameInitials,
      size: 80,
      isPremium: flow.isPremium,
    );

    final menuItems = [
     (
        icon: Icons.person_outline,
        label: 'Edit Profile',
        description: 'Update your photos and bio',
        action: () => Navigator.of(context).push(SmoothPageRoute(page: const EditProfilePage())),
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
        action: () => flow.push(AppStage.freezmePlus), // Using proper flow push
      ),
      (
        icon: Icons.notifications_outlined,
        label: 'Notifications',
        description: 'Choose what you get notified about',
        action: () => Navigator.of(context).push(SmoothPageRoute(page: const NotificationPrefsPage())),
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
                        const Flexible(
                          child: Text(
                            'Profile & Settings',
                            style: TextStyle(
                              color: FreezmeDesignSystem.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
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
                                    color: FreezmeDesignSystem.primary.withAlpha(25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(menuItems[i].icon, color: FreezmeDesignSystem.primary),
                                ),
                                title: Text(menuItems[i].label, style: FreezmeDesignSystem.bodyMedium),
                                subtitle: Text(menuItems[i].description, style: FreezmeDesignSystem.caption),
                                onTap: menuItems[i].action,
                                trailing: const Icon(Icons.chevron_right, color: FreezmeDesignSystem.textTertiary),
                              ),
                            ],
                            const Divider(indent: 60),
                            SwitchListTile(
                              value: flow.isFreezed,
                              onChanged: (value) => flow.toggleFreeze(value),
                              activeThumbColor: FreezmeDesignSystem.primary,
                              secondary: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.ac_unit, color: Colors.blue),
                              ),
                              title: const Text('Freeze Mode', style: FreezmeDesignSystem.bodyMedium),
                              subtitle: const Text('Pause matching & keep your vibe', style: FreezmeDesignSystem.caption),
                            ),
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
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => _confirmDeleteAccount(flow),
                          icon: const Icon(Icons.delete_forever_outlined, color: Colors.red, size: 18),
                          label: Text(
                            'Delete Account',
                            style: TextStyle(color: Colors.red.shade600),
                          ),
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
              color: FreezmeDesignSystem.primary.withAlpha(51),
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
                color: Colors.white.withAlpha(51),
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
                            backgroundColor: Colors.white.withAlpha(51),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${completion.toInt()}%',
                        style: TextStyle(
                          color: Colors.white.withAlpha(230),
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
                      color: Colors.white.withAlpha(217),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withAlpha(204),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: FreezmeDesignSystem.h3, overflow: TextOverflow.ellipsis),
                Text(label, style: FreezmeDesignSystem.small, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
