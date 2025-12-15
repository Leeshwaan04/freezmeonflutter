import 'package:flutter/material.dart';
import '../../main.dart';
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
  // TODO: Add gender preference if supported by backend

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
        setState(() {
          double min = (prefs['ageMin'] as num? ?? 18).toDouble();
          double max = (prefs['ageMax'] as num? ?? 35).toDouble();
          _ageRange = RangeValues(min, max);
          _distance = (prefs['distanceKm'] as num? ?? 10).toDouble();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      // Fallback defaults are already set
    }
  }



  @override
  Widget build(BuildContext context) {
    // Determine if we can save (bio issue logic handled later, for now we assume optional)
    
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
              onPressed: _isLoading ? null : _saveWithBioHandling,
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
                    onChanged: (values) {
                      setState(() => _ageRange = values);
                    },
                  ),
                  
                  const SizedBox(height: FreezmeDesignSystem.spaceXl),
                  
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
                    onChanged: (value) {
                      setState(() => _distance = value);
                    },
                  ),
                  
                  const SizedBox(height: FreezmeDesignSystem.spaceXl),
                  
                  // Gender Preference Placeholder
                  const Text('Show Me', style: FreezmeDesignSystem.h3),
                  const SizedBox(height: FreezmeDesignSystem.spaceMd),
                  PremiumCard(
                    padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
                    child: Column(
                      children: [
                        _buildRadioOption('Everyone', true), // Hardcoded for now
                        const Divider(color: FreezmeDesignSystem.border),
                        _buildRadioOption('Men', false),
                        const Divider(color: FreezmeDesignSystem.border),
                        _buildRadioOption('Women', false),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: FreezmeDesignSystem.spaceMd),
                   const Text(
                    'Gender filtering will be enabled in the next update.',
                    style: FreezmeDesignSystem.caption,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRadioOption(String label, bool selected) {
    return Row(
      children: [
        Text(label, style: FreezmeDesignSystem.bodyMedium),
        const Spacer(),
        if (selected)
          const Icon(Icons.check, color: FreezmeDesignSystem.primary),
      ],
    );
  }

  Future<void> _saveWithBioHandling() async {
    // Need to fetch bio first to avoid overwriting it with empty string
    setState(() => _isLoading = true);
    final flow = AppFlowScope.of(context, listen: false);
    String currentBio = '';
    try {
      final prefs = await flow.repository.fetchUserPreferences();
      currentBio = prefs['bio'] as String? ?? '';
    } catch (_) {
      // ignore
    }

    try {
      await flow.repository.updateUserPreferences(
        ageMin: _ageRange.start.round(),
        ageMax: _ageRange.end.round(),
        distanceKm: _distance,
        bio: currentBio, // Pass back existing bio
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
         PremiumSnackBar.show(context, 'Error saving preferences', type: SnackBarType.error);
         setState(() => _isLoading = false);
      }
    }
  }
}
