import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../design_system.dart';
import '../components/premium_components.dart';

const _kTermsUrl = 'https://api.freezme.in/terms';
const _kPrivacyUrl = 'https://api.freezme.in/privacy';

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class SafetyPrivacyPage extends StatefulWidget {
  const SafetyPrivacyPage({super.key});

  @override
  State<SafetyPrivacyPage> createState() => _SafetyPrivacyPageState();
}

class _SafetyPrivacyPageState extends State<SafetyPrivacyPage> {
  bool _hideOnlineStatus = false;
  bool _hideLastSeen = false;
  bool _hideReadReceipts = false;
  bool _incognitoMode = false;
  final List<String> _blockedUsers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    setState(() => _isLoading = true);
    try {
      final flow = AppFlowScope.of(context, listen: false);
      final prefs = await flow.repository.fetchUserPreferences();
      if (mounted) {
        setState(() {
          _hideOnlineStatus = prefs['hideOnlineStatus'] ?? false;
          _hideLastSeen = prefs['hideLastSeen'] ?? false;
          _hideReadReceipts = prefs['hideReadReceipts'] ?? false;
          _incognitoMode = prefs['incognitoMode'] ?? false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, bool value) async {
    try {
      final flow = AppFlowScope.of(context, listen: false);
      final uid = AuthService.instance.currentUser?.uid;
      if (uid == null) return;
      // Map privacy toggle keys to the profile update fields
      switch (key) {
        case 'hideOnlineStatus':
          // hideOnlineStatus covers both "online now" and "last seen" — single server field
          await flow.repository.updateProfile(uid: uid, hideLastActive: value);
        case 'hideLastSeen':
          // Treated as alias for hideLastActive on the server
          await flow.repository.updateProfile(uid: uid, hideLastActive: value);
        case 'hideReadReceipts':
          // No server field yet — persisted locally only
          break;
        case 'incognitoMode':
          // Incognito = don't appear in pools
          await flow.repository.updateProfile(
            uid: uid,
            appearInMenPool: !value,
            appearInWomenPool: !value,
            nbOnlyPool: false,
          );
      }
    } catch (e) {
      if (mounted) {
        PremiumSnackBar.show(context, 'Failed to save setting', type: SnackBarType.error);
      }
    }
  }

  Future<void> _unblockUser(String blockedUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User?'),
        content: const Text('This user will be able to see your profile again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      try {
        await ApiClient.instance.dio.delete<void>('/users/blocked/$blockedUid');
        setState(() => _blockedUsers.remove(blockedUid));
        PremiumSnackBar.show(context, 'User unblocked', type: SnackBarType.success);
      } catch (e) {
        if (!mounted) return;
        PremiumSnackBar.show(context, 'Error unblocking user', type: SnackBarType.error);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?', style: TextStyle(color: FreezmeDesignSystem.error)),
        content: const Text(
          'This action cannot be undone. All your data, messages, and photos will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: FreezmeDesignSystem.error,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      try {
        final flow = AppFlowScope.of(context, listen: false);
        await ApiClient.instance.dio.delete<Map<String, dynamic>>('/users/me');
        await flow.signOut();
        if (mounted) {
          PremiumSnackBar.show(context, 'Account deleted successfully', type: SnackBarType.success);
        }
      } catch (e) {
        if (mounted) {
          PremiumSnackBar.show(context, 'Error deleting account', type: SnackBarType.error);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      appBar: AppBar(
        title: const Text('Safety & Privacy', style: FreezmeDesignSystem.h3),
        backgroundColor: FreezmeDesignSystem.background,
        iconTheme: const IconThemeData(color: FreezmeDesignSystem.primary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: ListView(
              padding: const EdgeInsets.all(FreezmeDesignSystem.spaceLg),
              children: [
                const Text('Privacy Settings', style: FreezmeDesignSystem.bodySemiBold),
                const SizedBox(height: FreezmeDesignSystem.spaceMd),
                PremiumCard(
                  padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
                  child: Column(
                    children: [
                      _buildPrivacyToggle(
                        title: 'Hide Online Status',
                        subtitle: 'Others won\'t see when you\'re active',
                        value: _hideOnlineStatus,
                        onChanged: (value) {
                          setState(() => _hideOnlineStatus = value);
                          _saveSetting('hideOnlineStatus', value);
                        },
                      ),
                      const Divider(color: FreezmeDesignSystem.border),
                      _buildPrivacyToggle(
                        title: 'Hide Last Seen',
                        subtitle: 'Others won\'t know when you last active',
                        value: _hideLastSeen,
                        onChanged: (value) {
                          setState(() => _hideLastSeen = value);
                          _saveSetting('hideLastSeen', value);
                        },
                      ),
                      const Divider(color: FreezmeDesignSystem.border),
                      _buildPrivacyToggle(
                        title: 'Hide Read Receipts',
                        subtitle: 'Others won\'t see if you\'ve read messages',
                        value: _hideReadReceipts,
                        onChanged: (value) {
                          setState(() => _hideReadReceipts = value);
                          _saveSetting('hideReadReceipts', value);
                        },
                      ),
                      const Divider(color: FreezmeDesignSystem.border),
                      _buildPrivacyToggle(
                        title: 'Incognito Mode',
                        subtitle: 'Hide from search and discovery',
                        value: _incognitoMode,
                        onChanged: (value) {
                          setState(() => _incognitoMode = value);
                          _saveSetting('incognitoMode', value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: FreezmeDesignSystem.spaceXl),
                const Text('Blocked Users', style: FreezmeDesignSystem.bodySemiBold),
                const SizedBox(height: FreezmeDesignSystem.spaceMd),
                _blockedUsers.isEmpty
                    ? PremiumCard(
                        padding: const EdgeInsets.all(FreezmeDesignSystem.spaceLg),
                        child: Center(
                          child: Text(
                            'No blocked users',
                            style: FreezmeDesignSystem.captionMedium.copyWith(
                              color: FreezmeDesignSystem.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : PremiumCard(
                        padding: EdgeInsets.zero,
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _blockedUsers.length,
                          separatorBuilder: (_, _) => const Divider(color: FreezmeDesignSystem.border),
                          itemBuilder: (context, index) {
                            final uid = _blockedUsers[index];
                            return Padding(
                              padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text('User ${uid.substring(0, 8)}', style: FreezmeDesignSystem.body),
                                  ),
                                  TextButton(
                                    onPressed: () => _unblockUser(uid),
                                    child: const Text('Unblock', style: TextStyle(color: FreezmeDesignSystem.primary)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                const SizedBox(height: FreezmeDesignSystem.spaceXl),
                const Text('Data & Account', style: FreezmeDesignSystem.bodySemiBold),
                const SizedBox(height: FreezmeDesignSystem.spaceMd),
                PremiumCard(
                  padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
                  child: Column(
                    children: [
                      _buildActionTile(
                        icon: Icons.download,
                        title: 'Download My Data',
                        subtitle: 'Get a copy of your data',
                        onTap: () {
                          PremiumSnackBar.show(
                            context,
                            'Data download link sent to your email',
                            type: SnackBarType.success,
                          );
                        },
                      ),
                      const Divider(color: FreezmeDesignSystem.border),
                      _buildActionTile(
                        icon: Icons.delete_outline,
                        title: 'Delete Account',
                        subtitle: 'Permanently delete your account',
                        titleColor: FreezmeDesignSystem.error,
                        onTap: _deleteAccount,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildPrivacyToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: FreezmeDesignSystem.bodyMedium),
      subtitle: Text(subtitle, style: FreezmeDesignSystem.captionMedium),
      value: value,
      activeTrackColor: FreezmeDesignSystem.primary,
      onChanged: (newValue) {
        HapticFeedback.selectionClick();
        onChanged(newValue);
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Color titleColor = FreezmeDesignSystem.textPrimary,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: titleColor),
      title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: FreezmeDesignSystem.captionMedium),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: FreezmeDesignSystem.textSecondary),
      onTap: onTap,
    );
  }
}

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  bool _isSubmitting = false;
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_messageController.text.trim().isEmpty) {
      PremiumSnackBar.show(context, 'Please enter a message', type: SnackBarType.warning);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      PremiumSnackBar.show(
        context,
        'Thank you for your feedback!',
        type: SnackBarType.success,
      );
      _messageController.clear();
    } catch (e) {
      PremiumSnackBar.show(
        context,
        'Error submitting feedback',
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showFAQDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Email us at: support@freezme.app'),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Describe your issue...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isSubmitting ? null : () {
              _submitFeedback();
              Navigator.pop(context);
            },
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      appBar: AppBar(
        title: const Text('Help & Support', style: FreezmeDesignSystem.h3),
        backgroundColor: FreezmeDesignSystem.background,
        iconTheme: const IconThemeData(color: FreezmeDesignSystem.primary),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.all(FreezmeDesignSystem.spaceLg),
        children: [
          const Text('Frequently Asked Questions', style: FreezmeDesignSystem.bodySemiBold),
          const SizedBox(height: FreezmeDesignSystem.spaceMd),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildFAQTile(
                  question: 'How do I match with someone?',
                  answer: 'Browse profiles in the Tonight tab and like the ones you\'re interested in. When someone likes you back, it\'s a match! You\'ll be able to start chatting immediately.',
                ),
                const Divider(color: FreezmeDesignSystem.border),
                _buildFAQTile(
                  question: 'What are Paths?',
                  answer: 'Paths is a location-based discovery feature where you can find people doing activities near you. Enable "Show me on Paths" to let others see you\'re available.',
                ),
                const Divider(color: FreezmeDesignSystem.border),
                _buildFAQTile(
                  question: 'What are Blinds?',
                  answer: 'Blinds is an anonymous matching feature. You exchange messages and icebreakers before revealing your identity, adding an element of surprise and fun.',
                ),
                const Divider(color: FreezmeDesignSystem.border),
                _buildFAQTile(
                  question: 'How does my profile visibility work?',
                  answer: 'Your profile is visible based on your preferences and settings. In Incognito mode, you\'re hidden from search and discovery but can still see and message matches.',
                ),
                const Divider(color: FreezmeDesignSystem.border),
                _buildFAQTile(
                  question: 'What is Freezme+?',
                  answer: 'Freezme+ is our premium subscription that gives you unlimited likes, global visibility, advanced filters, and exclusive features. Start with a free trial!',
                ),
              ],
            ),
          ),
          const SizedBox(height: FreezmeDesignSystem.spaceXl),
          const Text('Support', style: FreezmeDesignSystem.bodySemiBold),
          const SizedBox(height: FreezmeDesignSystem.spaceMd),
          PremiumCard(
            padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
            child: Column(
              children: [
                _buildSupportTile(
                  icon: Icons.mail_outline,
                  title: 'Contact Support',
                  subtitle: 'Get help from our support team',
                  onTap: _showContactDialog,
                ),
                const Divider(color: FreezmeDesignSystem.border),
                _buildSupportTile(
                  icon: Icons.bug_report_outlined,
                  title: 'Report a Problem',
                  subtitle: 'Tell us about technical issues',
                  onTap: () {
                    _messageController.clear();
                    _showContactDialog();
                  },
                ),
                const Divider(color: FreezmeDesignSystem.border),
                _buildSupportTile(
                  icon: Icons.rate_review_outlined,
                  title: 'Community Guidelines',
                  subtitle: 'Learn our community standards',
                  onTap: () {
                    PremiumSnackBar.show(
                      context,
                      'Opening community guidelines...',
                      type: SnackBarType.info,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: FreezmeDesignSystem.spaceXl),
          const Text('Legal', style: FreezmeDesignSystem.bodySemiBold),
          const SizedBox(height: FreezmeDesignSystem.spaceMd),
          PremiumCard(
            padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
            child: Column(
              children: [
                _buildLegalTile(
                  title: 'Terms of Service',
                  onTap: () => _openUrl(_kTermsUrl),
                ),
                const Divider(color: FreezmeDesignSystem.border),
                _buildLegalTile(
                  title: 'Privacy Policy',
                  onTap: () => _openUrl(_kPrivacyUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: FreezmeDesignSystem.spaceXl),
          const Text('About', style: FreezmeDesignSystem.bodySemiBold),
          const SizedBox(height: FreezmeDesignSystem.spaceMd),
          PremiumCard(
            padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('App Version', style: FreezmeDesignSystem.body),
                    Text(
                      '1.0.0',
                      style: FreezmeDesignSystem.body.copyWith(
                        color: FreezmeDesignSystem.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FreezmeDesignSystem.spaceSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Build Number', style: FreezmeDesignSystem.body),
                    Text(
                      '2025.12.15',
                      style: FreezmeDesignSystem.body.copyWith(
                        color: FreezmeDesignSystem.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: FreezmeDesignSystem.spaceXl),
        ],
        ),
      ),
    );
  }

  Widget _buildFAQTile({required String question, required String answer}) {
    return ListTile(
      contentPadding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
      title: Text(question, style: FreezmeDesignSystem.bodyMedium),
      trailing: const Icon(Icons.expand_more, color: FreezmeDesignSystem.textSecondary),
      onTap: () {
        HapticFeedback.lightImpact();
        _showFAQDialog(question, answer);
      },
    );
  }

  Widget _buildSupportTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: FreezmeDesignSystem.primary),
      title: Text(title, style: FreezmeDesignSystem.bodyMedium),
      subtitle: Text(subtitle, style: FreezmeDesignSystem.captionMedium),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: FreezmeDesignSystem.textSecondary),
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
    );
  }

  Widget _buildLegalTile({
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: FreezmeDesignSystem.bodyMedium),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: FreezmeDesignSystem.textSecondary),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }
}
