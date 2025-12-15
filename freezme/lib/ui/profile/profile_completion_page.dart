import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main.dart';
import '../../models/vibe_profile.dart' as models;
import '../../services/photo_upload_service.dart';
import '../../services/location_service.dart';
import '../../services/geo_service.dart';
import '../design_system.dart';
import '../components/premium_components.dart';

class ProfileCompletionPage extends StatefulWidget {
  const ProfileCompletionPage({super.key});

  @override
  State<ProfileCompletionPage> createState() => _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends State<ProfileCompletionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();

  String? _photoUrl;
  String _gender = 'Prefer not to say';
  final Set<String> _lookingFor = {};
  double _distancePref = 10;
  
  // Location
  double? _lat;
  double? _lng;
  String? _geohash;
  String? _timezone;
  bool _loadingLocation = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _ageController.text = '18';
    _detectLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    if (!mounted) return;
    setState(() => _loadingLocation = true);
    try {
      final locationService = LocationService();
      final result = await locationService.getCoarseLocation();
      final timezone = await FlutterTimezone.getLocalTimezone();

      if (result.lat != null && result.lng != null) {
        final geoService = GeoService();
        final geohash = geoService.encodeGeohash(result.lat!, result.lng!, precision: 5);

        if (mounted) {
          setState(() {
            _lat = result.lat;
            _lng = result.lng;
            _geohash = geohash;
            _timezone = timezone;
          });
        }
      }
    } catch (e) {
      if (mounted) {
         PremiumSnackBar.show(context, 'Could not detect location: $e', type: SnackBarType.warning);
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _pickPhoto() async {
    final uploadService = FirebasePhotoUploadService();
    try {
      final result = await uploadService.pickAndUpload(slotIndex: 0);
      setState(() => _photoUrl = result.url);
    } catch (e) {
      if (mounted) {
         PremiumSnackBar.show(context, 'Photo upload failed: $e', type: SnackBarType.error);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_lookingFor.isEmpty) {
      PremiumSnackBar.show(context, 'Please select "Looking For" preferences', type: SnackBarType.warning);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      PremiumSnackBar.show(context, 'Please sign in to continue', type: SnackBarType.error);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profile = models.VibeProfile(
        uid: user.uid,
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text),
        imageUrl: _photoUrl ?? '',
        compatibility: 0,
        bio: _bioController.text.trim(),
        distance: '${_distancePref.toInt()}km',
        lat: _lat,
        lng: _lng,
        geohash: _geohash,
        timezone: _timezone,
        lastActive: DateTime.now(),
      );

      final flow = AppFlowScope.of(context, listen: false);
      await flow.repository.createProfile(profile);

      // Pseudo logic for sync flow state
      flow.updateLocalProfileState(
        hasBio: profile.bio.isNotEmpty,
        hasPreferences: true,
        photoSlot: _photoUrl != null 
            ? PhotoSlot(status: PhotoSlotStatus.uploaded, imageUrl: _photoUrl) 
            : null,
        photoIndex: 0,
      );

      if (mounted) {
        PremiumSnackBar.show(context, 'Profile Created!', type: SnackBarType.success);
        await flow.completeOnboarding();
      }

    } catch (e) {
      if (mounted) {
        PremiumSnackBar.show(context, 'Save failed: $e', type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: FreezmeDesignSystem.textPrimary),
          onPressed: () => AppFlowScope.of(context).openHome(),
        ),
        title: const Text('Complete Profile', style: FreezmeDesignSystem.h3),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(FreezmeDesignSystem.spaceLg),
                  children: [
                    // Photo Upload
                     Center(
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: FreezmeDesignSystem.surfaceAlt,
                                shape: BoxShape.circle,
                                border: Border.all(color: FreezmeDesignSystem.border, width: 2),
                                image: _photoUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_photoUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _photoUrl == null
                                  ? const Icon(Icons.person_add_alt_1, size: 40, color: FreezmeDesignSystem.primary)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: FreezmeDesignSystem.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit, size: 14, color: Colors.white),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: FreezmeDesignSystem.spaceLg),
                    
                    const Text('Basic Info', style: FreezmeDesignSystem.h3),
                    const SizedBox(height: FreezmeDesignSystem.spaceMd),

                    PremiumTextField(
                      controller: _nameController,
                      labelText: 'Display Name',
                      hintText: 'What should we call you?',
                      prefixIcon: Icons.person_outline,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: FreezmeDesignSystem.spaceMd),
                    
                    PremiumTextField(
                      controller: _ageController,
                      labelText: 'Age',
                      hintText: '18',
                      prefixIcon: Icons.calendar_today,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final val = int.tryParse(v ?? '');
                        if (val == null || val < 18) return 'Must be 18+';
                        return null;
                      },
                    ),
                    const SizedBox(height: FreezmeDesignSystem.spaceMd),

                    PremiumTextField(
                      controller: _bioController,
                      labelText: 'Bio',
                      hintText: 'Share your vibe...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: FreezmeDesignSystem.spaceXl),

                    const Text('Gender', style: FreezmeDesignSystem.h3),
                    const SizedBox(height: FreezmeDesignSystem.spaceMd),
                    Wrap(
                      spacing: 8, 
                      children: ['Male', 'Female', 'Non-binary', 'Prefer not to say'].map((g) {
                        final selected = _gender == g;
                        return PremiumChip(
                          label: g,
                          selected: selected,
                          onTap: () => setState(() => _gender = g),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: FreezmeDesignSystem.spaceXl),

                    const Text('Looking For', style: FreezmeDesignSystem.h3),
                    const SizedBox(height: FreezmeDesignSystem.spaceMd),
                    Wrap(
                      spacing: 8,
                      children: ['Men', 'Women', 'Everyone'].map((opt) {
                        final selected = _lookingFor.contains(opt);
                        return PremiumChip(
                          label: opt,
                          selected: selected,
                          onTap: () {
                            setState(() {
                              if (selected) _lookingFor.remove(opt);
                              else _lookingFor.add(opt);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: FreezmeDesignSystem.spaceXl),

                    // Location Status
                    if (_loadingLocation)
                      const Row(
                        children: [
                           SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                           SizedBox(width: 8),
                           Text('Locating...', style: FreezmeDesignSystem.caption),
                        ],
                      )
                    else if (_lat != null)
                      const Row(
                        children: [
                           Icon(Icons.location_on, color: FreezmeDesignSystem.success, size: 16),
                           SizedBox(width: 8),
                           Text('Location Secured', style: TextStyle(color: FreezmeDesignSystem.success)),
                        ],
                      ),
                      
                    const SizedBox(height: FreezmeDesignSystem.spaceMd),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Distance Preference', style: FreezmeDesignSystem.bodyMedium),
                        Text('${_distancePref.toInt()} km', style: FreezmeDesignSystem.h3.copyWith(color: FreezmeDesignSystem.primary)),
                      ],
                    ),
                    Slider(
                      value: _distancePref,
                      min: 5,
                      max: 100,
                      divisions: 19,
                      activeColor: FreezmeDesignSystem.primary,
                      onChanged: (v) => setState(() => _distancePref = v),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(FreezmeDesignSystem.spaceLg),
                child: PremiumButton(
                  label: 'Save Profile',
                  fullWidth: true,
                  loading: _isSaving,
                  onPressed: _saveProfile,
                  variant: ButtonVariant.filled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
