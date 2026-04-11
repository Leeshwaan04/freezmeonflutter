import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/flow_controller.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import 'package:dio/dio.dart' as dio_options;
import '../../services/api_client.dart';
import '../theme.dart';
import '../widgets/freezme_logo.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfileLevelUpFlow
//
// Post-onboarding optional upgrade flow. The current 7-step onboarding is
// NEVER touched. This is additive only.
//
// Screens shown per gender:
//   Everyone     → Preferences (gender pref, age range, distance)
//   Woman / NB   → Safety (messaging, visibility, hide active, verified-only)
//   Non-binary   → Pool Visibility (which pools to appear in)
//   Everyone     → IPV (gender-aware copy)
// ─────────────────────────────────────────────────────────────────────────────

class ProfileLevelUpFlow extends StatefulWidget {
  const ProfileLevelUpFlow({super.key});

  @override
  State<ProfileLevelUpFlow> createState() => _ProfileLevelUpFlowState();
}

class _ProfileLevelUpFlowState extends State<ProfileLevelUpFlow> {
  int _step = 0;
  bool _saving = false;

  // ── Preferences ─────────────────────────────────────────────────────────────
  final Set<String> _genderPrefs = {}; // 'Man', 'Woman', 'Non-binary', 'Everyone'
  double _ageMin = 18;
  double _ageMax = 40;
  double _distanceKm = 25;

  // ── Safety (Women / NB) ──────────────────────────────────────────────────────
  String _messagingPref = 'matches'; // 'matches' | 'anyone'
  bool _showExactDistance = true;
  bool _hideLastActive = false;
  bool _verifiedOnly = false;

  // ── Pool Visibility (NB only) ────────────────────────────────────────────────
  bool _appearInMenPool = true;
  bool _appearInWomenPool = true;
  bool _nbOnlyPool = false;

  // ── IPV ──────────────────────────────────────────────────────────────────────
  bool _ipvSubmitted = false;

  String? get _gender => AuthService.instance.currentUser?.gender;

  bool get _isWomanOrNB =>
      _gender == 'Woman' || _gender == 'Non-binary';

  bool get _isNB => _gender == 'Non-binary';

  List<_LevelUpScreen> get _screens {
    return [
      _LevelUpScreen(
        key: 'preferences',
        title: 'Who do you want to meet?',
        subtitle: 'This shapes your entire daily pool. Takes 30 seconds.',
        build: _buildPreferences,
      ),
      if (_isWomanOrNB)
        _LevelUpScreen(
          key: 'safety',
          title: 'Your safety, your rules.',
          subtitle: 'These settings are only visible to you.',
          build: _buildSafety,
        ),
      if (_isNB)
        _LevelUpScreen(
          key: 'pool',
          title: 'Where do you want to appear?',
          subtitle: 'Control which pools you show up in.',
          build: _buildPoolVisibility,
        ),
      _LevelUpScreen(
        key: 'ipv',
        title: _isWomanOrNB
            ? 'Only matched with verified users.'
            : 'Verified users get 2× more matches.',
        subtitle: _isWomanOrNB
            ? 'Your selfie is never stored or shown to others.'
            : 'Takes 30 seconds. Stays private.',
        build: _buildIPV,
      ),
    ];
  }

  bool _canProceed() {
    final screen = _screens[_step];
    switch (screen.key) {
      case 'preferences':
        return _genderPrefs.isNotEmpty;
      case 'safety':
        return true; // all have defaults
      case 'pool':
        return _nbOnlyPool || _appearInMenPool || _appearInWomenPool;
      case 'ipv':
        return true; // skippable
      default:
        return true;
    }
  }

  Future<void> _handleNext(AppFlowController flow) async {
    if (_step < _screens.length - 1) {
      setState(() => _step++);
      return;
    }
    // Last screen — save everything
    setState(() => _saving = true);
    try {
      final uid = AuthService.instance.currentUser?.uid;
      if (uid != null) {
        await flow.repository.updateProfile(
          uid: uid,
          genderPrefs: _genderPrefs.toList(),
          ageMin: _ageMin.round(),
          ageMax: _ageMax.round(),
          distanceKm: _distanceKm.round(),
          messagingPref: _messagingPref,
          showExactDistance: _showExactDistance,
          hideLastActive: _hideLastActive,
          verifiedOnly: _verifiedOnly,
          appearInMenPool: _isNB ? _appearInMenPool : null,
          appearInWomenPool: _isNB ? _appearInWomenPool : null,
          nbOnlyPool: _isNB ? _nbOnlyPool : null,
        );
      }
      await flow.completeLevelUp();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save: $e'),
            backgroundColor: FreezmeColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final screen = _screens[_step];
    final progress = (_step + 1) / _screens.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: FreezmeGradients.backgroundSoft),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const FreezmeLogo(size: LogoSize.sm, showText: true),
                        const Spacer(),
                        _LevelUpBadge(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 5,
                        backgroundColor: FreezmeColors.surfaceAlt,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            FreezmeColors.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(screen.title, style: FreezmeTypography.h1),
                    const SizedBox(height: 4),
                    Text(screen.subtitle, style: FreezmeTypography.bodyMuted),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  child: SingleChildScrollView(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: screen.build(context),
                  ),
                ),
              ),

              // Bottom nav
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    if (_step > 0)
                      IconButton.outlined(
                        onPressed: () => setState(() => _step--),
                        icon: const Icon(Icons.chevron_left),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _canProceed() && !_saving
                            ? () => _handleNext(flow)
                            : null,
                        style: FreezmeButtons.primaryFilled,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _step == _screens.length - 1
                                    ? 'Finish level-up ✨'
                                    : 'Continue',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Screen builders ────────────────────────────────────────────────────────

  Widget _buildPreferences(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Gender preference
        _SectionLabel('I want to meet'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ['Men', 'Women', 'Non-binary people', 'Everyone'].map((opt) {
            final key = opt == 'Men'
                ? 'Man'
                : opt == 'Women'
                    ? 'Woman'
                    : opt == 'Non-binary people'
                        ? 'Non-binary'
                        : 'Everyone';
            final selected = _genderPrefs.contains(key);
            return _SelectChip(
              label: opt,
              selected: selected,
              onTap: () => setState(() {
                if (key == 'Everyone') {
                  // "Everyone" clears all others
                  _genderPrefs.clear();
                  _genderPrefs.add('Everyone');
                } else {
                  _genderPrefs.remove('Everyone');
                  if (selected) {
                    _genderPrefs.remove(key);
                  } else {
                    _genderPrefs.add(key);
                  }
                }
              }),
            );
          }).toList(),
        ),
        if (_genderPrefs.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: _Hint('Select at least one'),
          ),

        const SizedBox(height: 32),

        // Age range
        _SectionLabel('Age range  ·  ${_ageMin.round()}–${_ageMax.round()}'),
        RangeSlider(
          values: RangeValues(_ageMin, _ageMax),
          min: 18,
          max: 65,
          divisions: 47,
          activeColor: FreezmeColors.primary,
          inactiveColor: FreezmeColors.surfaceAlt,
          labels: RangeLabels(
              _ageMin.round().toString(), _ageMax.round().toString()),
          onChanged: (v) => setState(() {
            if (v.end - v.start >= 2) {
              _ageMin = v.start;
              _ageMax = v.end;
            }
          }),
        ),

        const SizedBox(height: 24),

        // Distance
        _SectionLabel('Max distance  ·  ${_distanceKm.round()} km'),
        Slider(
          value: _distanceKm,
          min: 5,
          max: 100,
          divisions: 19,
          activeColor: FreezmeColors.primary,
          inactiveColor: FreezmeColors.surfaceAlt,
          label: '${_distanceKm.round()} km',
          onChanged: (v) => setState(() => _distanceKm = v),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('5 km', style: TextStyle(fontSize: 11, color: FreezmeColors.muted)),
            Text('100 km', style: TextStyle(fontSize: 11, color: FreezmeColors.muted)),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSafety(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Messaging preference
        _SectionLabel('Who can message you first?'),
        const SizedBox(height: 12),
        ...[
          ('matches', Icons.favorite_border, 'Matches only',
              'Only people you\'ve matched with can message you'),
          ('anyone', Icons.chat_bubble_outline, 'Anyone',
              'Any user can send you a message'),
        ].map((opt) {
          final (value, icon, label, sub) = opt;
          final selected = _messagingPref == value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OptionTile(
              icon: icon,
              label: label,
              sublabel: sub,
              selected: selected,
              onTap: () => setState(() => _messagingPref = value),
            ),
          );
        }),

        const SizedBox(height: 28),

        // Visibility toggles
        _SectionLabel('Profile visibility'),
        const SizedBox(height: 12),
        _ToggleRow(
          label: 'Show my exact distance',
          sublabel: 'Off = shown as "within 5 km" instead',
          value: _showExactDistance,
          onChanged: (v) => setState(() => _showExactDistance = v),
        ),
        const SizedBox(height: 12),
        _ToggleRow(
          label: 'Hide when I was last active',
          sublabel: 'Others won\'t see your last seen time',
          value: _hideLastActive,
          onChanged: (v) => setState(() => _hideLastActive = v),
        ),
        const SizedBox(height: 12),
        _ToggleRow(
          label: 'Only show me to verified profiles',
          sublabel: 'Reduces visibility but improves match quality',
          value: _verifiedOnly,
          onChanged: (v) => setState(() => _verifiedOnly = v),
        ),
        const SizedBox(height: 24),

        // Safety note
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF4FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('🔒', style: TextStyle(fontSize: 18)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'These settings are private. Freezme staff never see them. They only control what others can see about you.',
                  style: TextStyle(
                      fontSize: 12, color: FreezmeColors.neutral, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPoolVisibility(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'This controls which daily pools you appear in for other users. You can change this anytime.',
          style: TextStyle(fontSize: 13, color: FreezmeColors.muted, height: 1.5),
        ),
        const SizedBox(height: 24),

        _SectionLabel('Show me in...'),
        const SizedBox(height: 12),

        _ToggleRow(
          label: 'Men\'s pool',
          sublabel: 'You appear when men search for matches',
          value: _appearInMenPool && !_nbOnlyPool,
          onChanged: _nbOnlyPool
              ? null
              : (v) => setState(() => _appearInMenPool = v),
        ),
        const SizedBox(height: 12),
        _ToggleRow(
          label: 'Women\'s pool',
          sublabel: 'You appear when women search for matches',
          value: _appearInWomenPool && !_nbOnlyPool,
          onChanged: _nbOnlyPool
              ? null
              : (v) => setState(() => _appearInWomenPool = v),
        ),
        const SizedBox(height: 24),

        const Divider(),
        const SizedBox(height: 16),

        _ToggleRow(
          label: 'Non-binary only pool',
          sublabel: 'Only appear to users who also selected Non-binary',
          value: _nbOnlyPool,
          onChanged: (v) => setState(() {
            _nbOnlyPool = v;
            if (v) {
              _appearInMenPool = false;
              _appearInWomenPool = false;
            }
          }),
        ),

        if (!_nbOnlyPool && !_appearInMenPool && !_appearInWomenPool)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: _Hint('Select at least one pool to be visible to others'),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildIPV(BuildContext context) {
    final isWomanOrNB = _isWomanOrNB;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // Hero card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FreezmeColors.border),
          ),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _ipvSubmitted
                      ? const Color(0xFFD1FAE5)
                      : FreezmeColors.primary.withValues(alpha: 0.1),
                ),
                child: Icon(
                  _ipvSubmitted
                      ? Icons.verified_user
                      : Icons.face_retouching_natural,
                  size: 40,
                  color: _ipvSubmitted
                      ? const Color(0xFF059669)
                      : FreezmeColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _ipvSubmitted ? 'Selfie submitted ✓' : 'Photo Verification',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: FreezmeColors.neutral),
              ),
              const SizedBox(height: 8),
              Text(
                _ipvSubmitted
                    ? 'Verification usually takes under a minute. You\'ll get a notification when it\'s done.'
                    : 'Take a selfie to confirm you\'re a real person. It\'s never stored or shown to others.',
                style: const TextStyle(
                    fontSize: 13, color: FreezmeColors.muted, height: 1.5),
                textAlign: TextAlign.center,
              ),
              if (!_ipvSubmitted) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _takeSelfie,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Take selfie now'),
                  style: FilledButton.styleFrom(
                    backgroundColor: FreezmeColors.primary,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Benefits — gender-aware
        _SectionLabel(isWomanOrNB ? 'What verification gives you' : 'Why it\'s worth it'),
        const SizedBox(height: 12),
        ...(isWomanOrNB
            ? [
                ('🔒', 'Only matched with other verified users'),
                ('🚫', 'Bots and fake profiles can\'t reach you'),
                ('✅', 'Verified badge shown on your profile'),
                ('⬆️', 'Priority in the daily pool'),
              ]
            : [
                ('✅', 'Verified badge on your profile'),
                ('📈', '2× higher visibility in the daily pool'),
                ('🔒', 'Access to the verified-only match tier'),
                ('⚡', 'Faster matching — verified-first algorithm'),
              ])
            .map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Text(item.$1, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item.$2,
                            style: const TextStyle(
                                fontSize: 13, color: FreezmeColors.neutral)),
                      ),
                    ],
                  ),
                )),

        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _takeSelfie() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null || !mounted) return;

    try {
      // Step 1: get presigned S3 URL
      final urlResp = await ApiClient.instance.dio.post<Map<String, dynamic>>(
        '/verification/selfie-url',
      );
      final uploadUrl = urlResp.data!['uploadUrl'] as String;
      final selfieKey = urlResp.data!['selfieKey'] as String;

      // Step 2: PUT selfie directly to S3
      final bytes = await File(picked.path).readAsBytes();
      await ApiClient.instance.dio.put<void>(
        uploadUrl,
        data: bytes,
        options: dio_options.Options(
          headers: {'Content-Type': 'image/jpeg'},
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      // Step 3: submit selfieKey to EC2 → sets isVerified = true
      await ApiClient.instance.dio.post<void>(
        '/verification/submit',
        data: {'selfieKey': selfieKey},
      );

      if (mounted) setState(() => _ipvSubmitted = true);
    } catch (e) {
      debugPrint('[IPV] selfie upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selfie upload failed — try again'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen descriptor
// ─────────────────────────────────────────────────────────────────────────────

class _LevelUpScreen {
  const _LevelUpScreen({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.build,
  });
  final String key;
  final String title;
  final String subtitle;
  final Widget Function(BuildContext) build;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI components (local only)
// ─────────────────────────────────────────────────────────────────────────────

class _LevelUpBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        '✨ Level Up',
        style: TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: FreezmeColors.neutral,
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? FreezmeColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? FreezmeColors.primary : FreezmeColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : FreezmeColors.neutral,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? FreezmeColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? FreezmeColors.primary : FreezmeColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: selected ? Colors.white : FreezmeColors.neutral),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        color:
                            selected ? Colors.white : FreezmeColors.neutral,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      )),
                  Text(sublabel,
                      style: TextStyle(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.8)
                            : FreezmeColors.muted,
                        fontSize: 11,
                      )),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String sublabel;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FreezmeColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: FreezmeColors.neutral)),
                const SizedBox(height: 2),
                Text(sublabel,
                    style: const TextStyle(
                        fontSize: 11, color: FreezmeColors.muted)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: FreezmeColors.primary,
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline,
            size: 14, color: FreezmeColors.error),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 12, color: FreezmeColors.error)),
      ],
    );
  }
}
