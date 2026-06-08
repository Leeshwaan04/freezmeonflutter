import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../main.dart'; // For AppFlowScope, AppStage
import '../design_system.dart';
import '../components/premium_components.dart';
import '../components/aurora_background.dart';
import '../settings/preferences_page.dart';
import '../settings/settings_pages.dart';
import '../settings/notification_prefs_page.dart';
import 'edit_profile_page.dart';
import '../guides/feature_guides.dart';


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
        icon: Icons.auto_stories_outlined,
        label: 'How Freezme Works',
        description: 'Walkthroughs for Tonight, Paths, Blinds & more',
        action: () => showFeatureGuideHub(context),
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
                    // Left-aligned title, no logo, no back-arrow — Profile is a
                    // root tab, so a back button navigated to nothing. Matches
                    // the other tabs' header pattern.
                    const Text('Profile', style: FreezmeDesignSystem.h1),
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
                        const SizedBox(height: 8),
                        // Prominent delete-account entry — Apple Guideline 5.1.1
                        // requires account deletion to be easy to find.
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            SmoothPageRoute(page: DeleteAccountPage(flow: flow)),
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.withAlpha(40)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_forever_outlined, color: Colors.red.shade600, size: 20),
                                const SizedBox(width: 8),
                                Text('Delete Account',
                                    style: TextStyle(
                                      color: Colors.red.shade600,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ],
                            ),
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

// ── Delete Account dedicated page (Apple Guideline 5.1.1) ────────────────────
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key, required this.flow});
  final AppFlowController flow;

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _deleting = false;
  bool _confirmed = false;

  Future<void> _delete() async {
    if (!_confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please check the confirmation box first.')),
      );
      return;
    }
    setState(() => _deleting = true);
    try {
      await ApiClient.instance.dio.delete<Map<String, dynamic>>('/users/me');
      await widget.flow.signOut();
    } catch (e) {
      debugPrint('[Account] delete failed: $e');
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't delete your account. Please check your connection and try again."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      appBar: AppBar(
        backgroundColor: FreezmeDesignSystem.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Delete Account', style: FreezmeDesignSystem.h3),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withAlpha(40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 22),
                      const SizedBox(width: 8),
                      Text('This cannot be undone',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          )),
                    ]),
                    const SizedBox(height: 12),
                    const _BulletPoint(text: 'Your profile and photos will be permanently deleted'),
                    const _BulletPoint(text: 'All matches and conversations will be lost'),
                    const _BulletPoint(text: 'Any active Freezme+ subscription will not be refunded'),
                    const _BulletPoint(text: 'You will not be able to recover your account'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Want a break instead?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                'Freeze Mode pauses your profile — your matches and data stay safe until you return.',
                style: TextStyle(fontSize: 14, color: FreezmeDesignSystem.textSecondary),
              ),
              const Spacer(),
              CheckboxListTile(
                value: _confirmed,
                onChanged: (v) => setState(() => _confirmed = v ?? false),
                activeColor: Colors.red.shade600,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'I understand this will permanently delete my account and all data.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_deleting || !_confirmed) ? null : _delete,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    disabledBackgroundColor: Colors.red.withAlpha(80),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _deleting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Delete My Account Forever',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel — Keep My Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: FreezmeDesignSystem.textSecondary))),
        ],
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
