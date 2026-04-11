import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../design_system.dart';
import '../components/premium_components.dart';

class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  bool _isLoading = true;
  RangeValues _ageRange = const RangeValues(18, 35);
  double _distance = 10;
  // 'everyone' | 'men' | 'women' | 'nonbinary'
  String _showMe = 'everyone';

  static const _showMeOptions = [
    ('everyone', 'Everyone'),
    ('women',    'Women'),
    ('men',      'Men'),
    ('nonbinary','Non-binary'),
  ];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final flow = AppFlowScope.of(context, listen: false);
    try {
      final prefs = await flow.repository.fetchUserPreferences();
      if (mounted) {
        // genderPrefs is stored as a list; derive a single showMe value
        final raw = prefs['genderPrefs'];
        final List<String> gp = raw is List
            ? raw.whereType<String>().toList()
            : const [];

        String showMe = 'everyone';
        if (gp.length == 1) {
          if (gp.contains('woman')) {
            showMe = 'women';
          } else if (gp.contains('man')) {
            showMe = 'men';
          } else if (gp.contains('nonbinary')) {
            showMe = 'nonbinary';
          }
        }

        setState(() {
          _ageRange = RangeValues(
            (prefs['ageMin'] as num? ?? 18).toDouble(),
            (prefs['ageMax'] as num? ?? 35).toDouble(),
          );
          _distance = (prefs['distanceKm'] as num? ?? 10).toDouble();
          _showMe = showMe;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _genderPrefsPayload {
    switch (_showMe) {
      case 'women':    return ['woman'];
      case 'men':      return ['man'];
      case 'nonbinary':return ['nonbinary'];
      default:         return ['man', 'woman', 'nonbinary'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      appBar: AppBar(
        title: const Text('Preferences', style: FreezmeDesignSystem.h3),
        backgroundColor: FreezmeDesignSystem.background,
        iconTheme: const IconThemeData(color: FreezmeDesignSystem.primary),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _isLoading ? null : _save,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(FreezmeDesignSystem.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Age range
                  const Text('Age Range', style: FreezmeDesignSystem.h3),
                  const SizedBox(height: FreezmeDesignSystem.spaceSm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_ageRange.start.round()}', style: FreezmeDesignSystem.body),
                      Text('${_ageRange.end.round()}', style: FreezmeDesignSystem.body),
                    ],
                  ),
                  RangeSlider(
                    values: _ageRange,
                    min: 18,
                    max: 99,
                    divisions: 81,
                    activeColor: FreezmeDesignSystem.primary,
                    labels: RangeLabels(
                      _ageRange.start.round().toString(),
                      _ageRange.end.round().toString(),
                    ),
                    onChanged: (values) => setState(() => _ageRange = values),
                  ),

                  const SizedBox(height: FreezmeDesignSystem.spaceXl),

                  // Distance
                  const Text('Maximum Distance', style: FreezmeDesignSystem.h3),
                  const SizedBox(height: FreezmeDesignSystem.spaceSm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('1 km', style: FreezmeDesignSystem.body),
                      Text('${_distance.round()} km', style: FreezmeDesignSystem.body),
                    ],
                  ),
                  Slider(
                    value: _distance,
                    min: 1,
                    max: 100,
                    divisions: 99,
                    activeColor: FreezmeDesignSystem.primary,
                    label: '${_distance.round()} km',
                    onChanged: (value) => setState(() => _distance = value),
                  ),

                  const SizedBox(height: FreezmeDesignSystem.spaceXl),

                  // Gender preference
                  const Text('Show Me', style: FreezmeDesignSystem.h3),
                  const SizedBox(height: FreezmeDesignSystem.spaceMd),
                  PremiumCard(
                    padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
                    child: Column(
                      children: [
                        for (int i = 0; i < _showMeOptions.length; i++) ...[
                          if (i > 0) const Divider(color: FreezmeDesignSystem.border),
                          _buildRadioOption(
                            _showMeOptions[i].$2,
                            _showMe == _showMeOptions[i].$1,
                            () => setState(() => _showMe = _showMeOptions[i].$1),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRadioOption(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: FreezmeDesignSystem.bodyMedium),
            const Spacer(),
            if (selected)
              const Icon(Icons.check, color: FreezmeDesignSystem.primary),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    final flow = AppFlowScope.of(context, listen: false);

    // Fetch existing bio so we don't wipe it
    String currentBio = '';
    try {
      final prefs = await flow.repository.fetchUserPreferences();
      currentBio = prefs['bio'] as String? ?? '';
    } catch (_) {}

    try {
      // Save age/distance/bio via updateUserPreferences
      await flow.repository.updateUserPreferences(
        ageMin: _ageRange.start.round(),
        ageMax: _ageRange.end.round(),
        distanceKm: _distance,
        bio: currentBio,
      );

      // Save genderPrefs via updateProfile
      final uid = AuthService.instance.currentUser?.uid;
      if (uid != null) {
        await flow.repository.updateProfile(
          uid: uid,
          genderPrefs: _genderPrefsPayload,
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        PremiumSnackBar.show(context, 'Error saving preferences', type: SnackBarType.error);
        setState(() => _isLoading = false);
      }
    }
  }
}
