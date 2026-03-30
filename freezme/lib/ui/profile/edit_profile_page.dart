import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../design_system.dart';
import '../components/premium_components.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _hasUnsavedChanges = false;

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _ageController;
  late TextEditingController _locationController;

  List<String> _selectedInterests = [];
  final int _maxInterests = 10;

  @override
  void initState() {
    super.initState();
    // In a real app, we'd fetch this from the repo
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _ageController = TextEditingController();
    _locationController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final flow = AppFlowScope.of(context, listen: false);
      setState(() {
        _nameController.text = flow.fullProfile?.name ?? flow.profileName ?? '';
        _bioController.text = flow.fullProfile?.bio ?? '';
        if (flow.fullProfile?.age != null && flow.fullProfile!.age > 0) {
            _ageController.text = flow.fullProfile!.age.toString();
        }
        _locationController.text = flow.fullProfile?.distance ?? '';
        _selectedInterests = List.from(flow.fullProfile?.interests ?? []);
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedInterests.isEmpty) {
      PremiumSnackBar.show(context, 'Please select at least one interest', type: SnackBarType.warning);
      return;
    }

    setState(() => _saving = true);

    try {
      final flow = AppFlowScope.of(context, listen: false);
      final uid = AuthService.instance.currentUser?.uid;
      
      if (uid == null) throw Exception('User not logged in');

      await flow.repository.updateProfile(
        uid: uid,
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        age: int.tryParse(_ageController.text),
        location: _locationController.text.trim(),
        interests: _selectedInterests,
      );

      // Local state update
      await flow.setBioFilled(_bioController.text.trim().isNotEmpty);
      await flow.setPreferencesSet(_selectedInterests.isNotEmpty);
      await flow.refreshProfile();

      if (mounted) {
        PremiumSnackBar.show(context, 'Profile updated successfully', type: SnackBarType.success);
        setState(() => _hasUnsavedChanges = false);
        flow.pop();
      }
    } catch (e) {
      if (mounted) {
        PremiumSnackBar.show(context, 'Error saving profile: $e', type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleInterest(String interest) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        if (_selectedInterests.length < _maxInterests) {
          _selectedInterests.add(interest);
          HapticFeedback.mediumImpact();
        } else {
          PremiumSnackBar.show(context, 'Maximum $_maxInterests interests allowed', type: SnackBarType.info);
          HapticFeedback.heavyImpact();
        }
      }
      _hasUnsavedChanges = true;
    });
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Discard changes?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: FreezmeDesignSystem.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: FreezmeDesignSystem.background,
        appBar: AppBar(
          title: const Text('Edit Profile', style: FreezmeDesignSystem.h3),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _saving ? null : _saveProfile,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, color: FreezmeDesignSystem.primary)),
            )
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            onChanged: () {
               if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
            },
            child: ListView(
              padding: const EdgeInsets.all(FreezmeDesignSystem.spaceLg),
              children: [
                PremiumTextField(
                  controller: _nameController,
                  labelText: 'Name',
                  validator: (v) => (v == null || v.length < 2) ? 'Name too short' : null,
                ),
                const SizedBox(height: FreezmeDesignSystem.spaceLg),
                
                PremiumTextField(
                  controller: _bioController,
                  labelText: 'Bio',
                  maxLines: 4,
                  maxLength: 500,
                  validator: (v) => (v != null && v.length > 500) ? 'Bio too long' : null,
                ),
                const SizedBox(height: FreezmeDesignSystem.spaceLg),

                Row(
                  children: [
                    Expanded(
                      child: PremiumTextField(
                        controller: _ageController,
                        labelText: 'Age',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                           final age = int.tryParse(v ?? '');
                           if (age != null && (age < 18 || age > 99)) return 'Invalid';
                           return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: PremiumTextField(
                        controller: _locationController,
                        labelText: 'Location',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FreezmeDesignSystem.spaceXl),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Interests', style: FreezmeDesignSystem.h3),
                    Text('${_selectedInterests.length}/$_maxInterests', style: FreezmeDesignSystem.caption),
                  ],
                ),
                const SizedBox(height: FreezmeDesignSystem.spaceMd),
                
                Container(
                  padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
                  decoration: FreezmeDesignSystem.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategory('Hobbies', ['Music', 'Travel', 'Art', 'Gaming', 'Reading']),
                      const SizedBox(height: 16),
                      _buildCategory('Sports', ['Yoga', 'Gym', 'Running', 'Hiking']),
                      const SizedBox(height: 16),
                      _buildCategory('Lifestyle', ['Coffee', 'Foodie', 'Nightlife', 'Movies']),
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

  Widget _buildCategory(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: FreezmeDesignSystem.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final selected = _selectedInterests.contains(item);
            return PremiumChip(
              label: item,
              selected: selected,
              onTap: () => _toggleInterest(item),
            );
          }).toList(),
        ),
      ],
    );
  }
}
