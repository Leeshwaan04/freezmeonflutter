import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/photo_upload_service.dart';
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

  String? _gender;
  String? _intent;
  List<String> _selectedInterests = [];
  final int _maxInterests = 10;

  // Photos — up to 6 slots
  static const int _maxPhotos = 6;
  List<String> _existingPhotoUrls = [];   // loaded from server
  List<File?> _newPhotos = List.filled(6, null); // newly picked per slot
  bool _uploadingPhoto = false;

  static const _genderOptions = ['Man', 'Woman', 'Non-binary', 'Prefer not to say'];
  static const _intentOptions = [
    ('💜', 'Something real', 'meaningful'),
    ('✨', 'Open to see', 'exploring'),
    ('🤝', 'Connection first', 'friendship'),
  ];

  static const _interestCategories = {
    'Hobbies': ['Music', 'Travel', 'Art', 'Gaming', 'Reading', 'Photography', 'Cooking', 'Writing'],
    'Sports': ['Yoga', 'Gym', 'Running', 'Hiking', 'Cycling', 'Swimming', 'Climbing'],
    'Lifestyle': ['Coffee', 'Foodie', 'Nightlife', 'Movies', 'Wine', 'Concerts', 'Theatre'],
    'Values': ['Mindfulness', 'Sustainability', 'Volunteering', 'Spirituality', 'Family'],
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _ageController = TextEditingController();
    _locationController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = AuthService.instance.currentUser;
      final flow = AppFlowScope.of(context, listen: false);
      setState(() {
        _nameController.text = user?.displayName ?? flow.profileName ?? '';
        _bioController.text = user?.bio ?? flow.profileBio ?? '';
        final age = user?.age ?? flow.profileAge;
        if (age != null && age > 0) _ageController.text = age.toString();
        _existingPhotoUrls = user?.photoUrls.isNotEmpty == true
            ? user!.photoUrls
            : (user?.photoUrl != null ? [user!.photoUrl!] : []);
        // The server stores gender normalized + lowercase ('woman'); map it back
        // to the capitalized chip label so it pre-selects (was comparing
        // 'woman' == 'Woman' → gender always showed blank in Edit Profile).
        _gender = _genderToOption(user?.gender);
        _intent = user?.intent;
        // Canonicalize stored interests to chip labels (case-insensitive) so
        // they pre-select regardless of stored casing.
        final storedInterests = user?.interests.isNotEmpty == true
            ? user!.interests
            : flow.profileInterests;
        _selectedInterests = storedInterests.map(_canonicalInterest).toList();
      });
    });
  }

  /// Map the server's normalized gender ('man'/'woman'/'nonbinary'/'other')
  /// back to the capitalized display option so the chip pre-selects.
  String? _genderToOption(String? g) {
    if (g == null) return null;
    final k = g.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
    switch (k) {
      case 'man':
      case 'male':
        return 'Man';
      case 'woman':
      case 'female':
        return 'Woman';
      case 'nonbinary':
        return 'Non-binary';
      case 'other':
      case 'prefernottosay':
      case 'prefernot':
        return 'Prefer not to say';
      default:
        return null;
    }
  }

  /// Map a stored interest to its canonical chip label (case-insensitive) so
  /// pre-selection works regardless of stored casing.
  String _canonicalInterest(String stored) {
    for (final list in _interestCategories.values) {
      for (final chip in list) {
        if (chip.toLowerCase() == stored.toLowerCase()) return chip;
      }
    }
    return stored;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  static const _kMaxPhotoBytes = 8 * 1024 * 1024; // 8 MB

  Future<void> _pickPhoto(int slotIndex) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    // Enforce 8 MB limit before attempting S3 upload
    final file = File(picked.path);
    final bytes = await file.length();
    if (bytes > _kMaxPhotoBytes) {
      PremiumSnackBar.show(
        context,
        'Photo is too large (max 8 MB). Please choose a smaller image.',
        type: SnackBarType.warning,
      );
      return;
    }

    setState(() {
      _newPhotos = List.from(_newPhotos)..[slotIndex] = file;
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final flow = AppFlowScope.of(context, listen: false);
      final uid = AuthService.instance.currentUser?.uid;

      // Upload any new photos and merge with existing URLs
      setState(() => _uploadingPhoto = true);
      final List<String> finalPhotoUrls = List.from(_existingPhotoUrls);
      try {
        for (int i = 0; i < _maxPhotos; i++) {
          final newFile = _newPhotos[i];
          if (newFile == null) continue;
          final uploadedUrl = await S3PhotoUploadService().uploadPhoto(
            newFile, userId: uid ?? '', photoIndex: i,
          );
          if (i < finalPhotoUrls.length) {
            finalPhotoUrls[i] = uploadedUrl;
          } else {
            finalPhotoUrls.add(uploadedUrl);
          }
        }
      } catch (e) {
        if (mounted) {
          PremiumSnackBar.show(context, 'Some photos failed to upload',
              type: SnackBarType.warning);
        }
      } finally {
        if (mounted) setState(() => _uploadingPhoto = false);
      }
      final imageUrl = finalPhotoUrls.isNotEmpty ? finalPhotoUrls.first : null;

      if (uid != null) {
        await flow.repository.updateProfile(
          uid: uid,
          displayName: _nameController.text.trim(),
          bio: _bioController.text.trim(),
          age: int.tryParse(_ageController.text),
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          interests: _selectedInterests,
          gender: _gender,
          intent: _intent,
          imageUrl: imageUrl,
        );
        await flow.refreshProfile();
      } else {
        await flow.updateOnboardingData(
          name: _nameController.text.trim(),
          bio: _bioController.text.trim(),
          age: int.tryParse(_ageController.text),
          interests: _selectedInterests,
          gender: _gender,
          imageUrl: imageUrl,
        );
      }

      await flow.setBioFilled(_bioController.text.trim().isNotEmpty);
      await flow.setPreferencesSet(_selectedInterests.isNotEmpty);

      if (mounted) {
        PremiumSnackBar.show(context, 'Profile updated', type: SnackBarType.success);
        setState(() => _hasUnsavedChanges = false);
        flow.pop();
      }
    } catch (e) {
      if (mounted) {
        PremiumSnackBar.show(context, 'Error saving profile: $e',
            type: SnackBarType.error);
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
      } else if (_selectedInterests.length < _maxInterests) {
        _selectedInterests.add(interest);
        HapticFeedback.mediumImpact();
      } else {
        PremiumSnackBar.show(context, 'Maximum $_maxInterests interests allowed',
            type: SnackBarType.info);
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: FreezmeDesignSystem.error),
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
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: FreezmeDesignSystem.primary)),
            ),
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
                // ── Photo ─────────────────────────────────────────────────
                _buildPhotoSection(),
                const SizedBox(height: FreezmeDesignSystem.spaceXl),

                // ── Name ──────────────────────────────────────────────────
                PremiumTextField(
                  controller: _nameController,
                  labelText: 'First name',
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'Name too short' : null,
                ),
                const SizedBox(height: FreezmeDesignSystem.spaceLg),

                // ── Bio ───────────────────────────────────────────────────
                PremiumTextField(
                  controller: _bioController,
                  labelText: 'Bio',
                  maxLines: 4,
                  maxLength: 500,
                  validator: (v) =>
                      (v != null && v.length > 500) ? 'Bio too long' : null,
                ),
                const SizedBox(height: FreezmeDesignSystem.spaceLg),

                // ── Age + Location ────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: PremiumTextField(
                        controller: _ageController,
                        labelText: 'Age',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final age = int.tryParse(v ?? '');
                          if (age != null && (age < 18 || age > 99)) {
                            return 'Must be 18–99';
                          }
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

                // ── Gender ────────────────────────────────────────────────
                _buildSectionHeader('How you identify'),
                const SizedBox(height: FreezmeDesignSystem.spaceMd),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _genderOptions.map((g) {
                    final selected = _gender == g;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _gender = g;
                        _hasUnsavedChanges = true;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? FreezmeDesignSystem.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? FreezmeDesignSystem.primary
                                : FreezmeDesignSystem.border,
                          ),
                        ),
                        child: Text(
                          g,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : FreezmeDesignSystem.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: FreezmeDesignSystem.spaceXl),

                // ── Intent ────────────────────────────────────────────────
                _buildSectionHeader('What you\'re here for'),
                const SizedBox(height: FreezmeDesignSystem.spaceMd),
                ..._intentOptions.map((opt) {
                  final (emoji, label, value) = opt;
                  final selected = _intent == value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _intent = value;
                        _hasUnsavedChanges = true;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? FreezmeDesignSystem.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? FreezmeDesignSystem.primary
                                : FreezmeDesignSystem.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(emoji,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Text(
                              label,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : FreezmeDesignSystem.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            if (selected) ...[
                              const Spacer(),
                              const Icon(Icons.check_circle,
                                  color: Colors.white, size: 18),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: FreezmeDesignSystem.spaceXl),

                // ── Interests ─────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('Interests'),
                    Text('${_selectedInterests.length}/$_maxInterests',
                        style: FreezmeDesignSystem.caption),
                  ],
                ),
                const SizedBox(height: FreezmeDesignSystem.spaceMd),
                Container(
                  padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
                  decoration: FreezmeDesignSystem.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _interestCategories.entries.map((cat) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat.key,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: FreezmeDesignSystem.textSecondary,
                                letterSpacing: 0.5,
                              )),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: cat.value.map((item) {
                              final selected =
                                  _selectedInterests.contains(item);
                              return PremiumChip(
                                label: item,
                                selected: selected,
                                onTap: () => _toggleInterest(item),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: FreezmeDesignSystem.spaceXl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Photos', style: FreezmeDesignSystem.h3),
            Text(
              '${(_existingPhotoUrls.length + _newPhotos.where((f) => f != null).length).clamp(0, _maxPhotos)}/$_maxPhotos',
              style: FreezmeDesignSystem.caption,
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.75,
          ),
          itemCount: _maxPhotos,
          itemBuilder: (context, i) => _buildPhotoSlot(i),
        ),
        if (_uploadingPhoto)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Uploading photos…',
                      style: TextStyle(fontSize: 12,
                          color: FreezmeDesignSystem.textSecondary)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoSlot(int i) {
    final newFile = _newPhotos[i];
    final existingUrl = i < _existingPhotoUrls.length ? _existingPhotoUrls[i] : null;
    final hasContent = newFile != null || existingUrl != null;
    final isFirst = i == 0;

    return GestureDetector(
      onTap: () => _pickPhoto(i),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasContent
                ? FreezmeDesignSystem.primary
                : FreezmeDesignSystem.border,
            width: hasContent ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (newFile != null)
                Image.file(newFile, fit: BoxFit.cover)
              else if (existingUrl != null)
                Image.network(existingUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _emptySlot(i, isFirst))
              else
                _emptySlot(i, isFirst),
              // "Main" badge on first slot
              if (isFirst && hasContent)
                Positioned(
                  bottom: 4, left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: FreezmeDesignSystem.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Main',
                        style: TextStyle(color: Colors.white,
                            fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
              // Camera icon overlay
              Positioned(
                bottom: 4, right: 4,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: hasContent
                        ? FreezmeDesignSystem.primary
                        : const Color(0xFFD1D5DB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasContent ? Icons.edit : Icons.add,
                    size: 14, color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptySlot(int i, bool isFirst) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isFirst ? Icons.person_outline : Icons.add_photo_alternate_outlined,
          size: 28,
          color: FreezmeDesignSystem.textSecondary,
        ),
        const SizedBox(height: 4),
        Text(
          isFirst ? 'Main photo' : 'Add',
          style: const TextStyle(
              fontSize: 10, color: FreezmeDesignSystem.textSecondary),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: FreezmeDesignSystem.h3);
  }
}
