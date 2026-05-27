import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../../main.dart';
import '../components/premium_components.dart';
import '../components/freezme_logo.dart';

/// Premium 8-Step Onboarding Flow (Hinge-Style)
class EnhancedOnboardingFlow extends StatefulWidget {
  const EnhancedOnboardingFlow({super.key});

  @override
  State<EnhancedOnboardingFlow> createState() => _EnhancedOnboardingFlowState();
}

class _EnhancedOnboardingFlowState extends State<EnhancedOnboardingFlow>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 9; // Added Gender

  // Animation controllers
  late AnimationController _progressController;
  late AnimationController _fadeController;

  // Collected data
  String _name = '';
  DateTime? _birthDate;
  String _gender = '';
  final List<String> _selectedInterests = [];
  final List<String> _lookingFor = [];
  String? _vibeType;
  String _bio = '';
  bool _isLoading = false;

  // Interests
  final List<_InterestItem> _interests = const [
    _InterestItem('music', '🎵', 'Music'),
    _InterestItem('movies', '🎬', 'Movies'),
    _InterestItem('travel', '✈️', 'Travel'),
    _InterestItem('food', '🍕', 'Foodie'),
    _InterestItem('fitness', '🏃', 'Fitness'),
    _InterestItem('gaming', '🎮', 'Gaming'),
    _InterestItem('reading', '📚', 'Reading'),
    _InterestItem('art', '🎨', 'Art'),
    _InterestItem('photography', '📷', 'Photography'),
    _InterestItem('hiking', '🥾', 'Hiking'),
    _InterestItem('cooking', '👨‍🍳', 'Cooking'),
    _InterestItem('dancing', '💃', 'Dancing'),
    _InterestItem('yoga', '🧘', 'Yoga'),
    _InterestItem('pets', '🐕', 'Pets'),
    _InterestItem('coffee', '☕', 'Coffee'),
    _InterestItem('nightlife', '🌙', 'Nightlife'),
    _InterestItem('sports', '⚽', 'Sports'),
    _InterestItem('fashion', '👗', 'Fashion'),
    _InterestItem('tech', '💻', 'Tech'),
    _InterestItem('nature', '🌿', 'Nature'),
  ];

  // Looking for options
  final List<_LookingForItem> _lookingForOptions = const [
    _LookingForItem('casual', '🎉', 'Something Casual', 'Fun without pressure'),
    _LookingForItem('dating', '💜', 'Dating', 'Getting to know someone'),
    _LookingForItem('relationship', '💍', 'Relationship', 'Something serious'),
    _LookingForItem('friends', '🤝', 'New Friends', 'Expanding my circle'),
  ];
  
  // Vibe Types
  final List<_VibeTypeItem> _vibeTypes = const [
    _VibeTypeItem('chill', '🍵', 'Chill & Mellow', 'Low key vibes, deep talks'),
    _VibeTypeItem('energetic', '⚡', 'High Energy', 'Always down for adventure'),
    _VibeTypeItem('creative', '🎨', 'Creative Soul', 'Artistic and expressive'),
    _VibeTypeItem('ambitious', '💼', 'Ambitious', 'Focused on goals and growth'),
  ];

  // State for Bio Step
  final List<String> _bioPrompts = [
    "I usually spend my Sundays...",
    "I'm obsessed with...",
    "My golden rule is...",
    "A secret talent of mine...",
    "I'm looking for someone who...",
  ];
  bool _isGeneratingBio = false;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: _bio);
    _bioController.addListener(() {
      setState(() {
        _bio = _bioController.text;
      });
    });
    // ... rest of initState
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bioController.dispose();
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _haptic() => HapticFeedback.lightImpact();
  void _heavyHaptic() => HapticFeedback.heavyImpact();

  void _nextStep() {
    _haptic();
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousStep() {
    _haptic();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isLoading = true);
    _heavyHaptic();
    final controller = AppFlowScope.of(context);
    
    // Calculate age
    final age = _birthDate != null
        ? DateTime.now().difference(_birthDate!).inDays ~/ 365
        : null;

    // Save full profile to backend
    await controller.updateProfile(
      name: _name,
      bio: _bio,
      interests: _selectedInterests,
      age: age,
      gender: _gender,
    );

    controller.completeOnboarding();
    // No set state needed as we navigate away
  }

  bool _canProceed() {
    final controller = AppFlowScope.of(context);
    switch (_currentStep) {
      case 0: return true; // Welcome
      case 1: return _name.length >= 2; // Name
      case 2: { // Birthday — must be 18+
        if (_birthDate == null) return false;
        final age = DateTime.now().difference(_birthDate!).inDays ~/ 365;
        return age >= 18;
      }
      case 3: return _gender.isNotEmpty; // Gender
      case 4: return _selectedInterests.length >= 3; // Interests
      case 5: return controller.uploadedPhotoCount >= 2; // Photos (Require 2)
      case 6: return _bio.length >= 10; // Bio
      case 7: return _lookingFor.isNotEmpty; // Looking For
      case 8: return _vibeType != null; // Vibe Type
      default: return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFAF9FF), // Creamy white
              Color(0xFFF3E8FF), // Soft lavender
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildWelcomeStep(),        // 0
                    _buildNameStep(),           // 1
                    _buildBirthdayStep(),       // 2
                    _buildGenderStep(),         // 3 (New)
                    _buildInterestsStep(),      // 4
                    _buildPhotosStep(),         // 5
                    _buildBioStep(),            // 6
                    _buildLookingForStep(),     // 7
                    _buildVibeTypeStep(),       // 8
                  ],
                ),
              ),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                GestureDetector(
                  onTap: _previousStep,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Icon(Icons.arrow_back, color: FreezmeColors.primary),
                  ),
                )
              else
                const SizedBox(width: 40),
                
              // Step indicator pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  'Step ${_currentStep + 1} of $_totalSteps',
                  style: const TextStyle(
                    color: FreezmeColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              
              const SizedBox(width: 40), // Balance the back button
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Row(
              children: List.generate(_totalSteps, (index) {
                final isActive = index <= _currentStep;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 4,
                    decoration: BoxDecoration(
                      color: isActive
                          ? FreezmeColors.primary
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final canProceed = _canProceed();
    final isLastStep = _currentStep == _totalSteps - 1;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: PremiumButton(
          label: isLastStep ? "Complete Profile" : 'Continue',
          onPressed: canProceed && !_isLoading ? _nextStep : null,
          icon: isLastStep ? Icons.check_circle : Icons.arrow_forward_rounded,
          // variant defaults to filled (primary)
          loading: _isLoading,
        ),
      ),
    );
  }

  Widget _buildTitle(String title, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // Step 0: Welcome
  Widget _buildWelcomeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Hero(
            tag: 'freezme_logo',
            child: FreezmeLogo(size: LogoSize.hero, variant: LogoVariant.primary),
          ),
          const SizedBox(height: 32),
          _buildTitle(
            "Welcome to Freezme",
            "Let's build your profile so you can start\nmaking meaningful connections today.",
          ),
          _buildWelcomeFeature(Icons.access_time_filled_rounded, 'Takes about 2 mins'),
          const SizedBox(height: 16),
          _buildWelcomeFeature(Icons.photo_library_rounded, 'Add 2+ photos', active: true),
          const SizedBox(height: 16),
          _buildWelcomeFeature(Icons.edit_note_rounded, 'Write a short bio', active: true),
        ],
      ),
    );
  }

  Widget _buildWelcomeFeature(IconData icon, String text, {bool active = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: active ? FreezmeColors.primary : Colors.grey.shade400),
          const SizedBox(width: 16),
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: active ? Colors.black87 : Colors.grey.shade600,
            ),
          ),
          if (active) ...[
            const Spacer(),
            const Icon(Icons.check_circle_outline, color: FreezmeColors.success, size: 20),
          ],
        ],
      ),
    );
  }

  // Step 1: Name
  Widget _buildNameStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildTitle("What's your name?", "This is how you'll appear to others."),
          TextField(
            onChanged: (value) => setState(() => _name = value),
            textCapitalization: TextCapitalization.words,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: 'First Name',
              hintStyle: TextStyle(color: Colors.grey.shade300),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  // Step 2: Birthday
  Widget _buildBirthdayStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildTitle("When's your birthday?", "You must be 18+ to use Freezme."),
          GestureDetector(
            onTap: () async {
              _haptic();
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 365 * 21)),
                firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
                lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(primary: FreezmeColors.primary),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) setState(() => _birthDate = date);
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _birthDate != null ? FreezmeColors.primary : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: _birthDate != null ? FreezmeColors.primary : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _birthDate != null
                        ? '${_birthDate!.month}/${_birthDate!.day}/${_birthDate!.year}'
                        : 'MM / DD / YYYY',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _birthDate != null ? FreezmeColors.primary : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 3: Gender
  Widget _buildGenderStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          _buildTitle("How do you identify?", "Your gender is shown on your profile."),
          const SizedBox(height: 32),
          _buildSelectableOption('Man', _gender == 'Man', () => setState(() => _gender = 'Man')),
          const SizedBox(height: 12),
          _buildSelectableOption('Woman', _gender == 'Woman', () => setState(() => _gender = 'Woman')),
          const SizedBox(height: 12),
          _buildSelectableOption('Non-binary', _gender == 'Non-binary', () => setState(() => _gender = 'Non-binary')),
          const SizedBox(height: 12),
          _buildSelectableOption('Prefer not to say', _gender == 'Prefer not to say', () => setState(() => _gender = 'Prefer not to say')),
        ],
      ),
    );
  }

  Widget _buildSelectableOption(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
         _haptic();
         onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? FreezmeColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? FreezmeColors.primary : Colors.grey.shade200,
          ),
          boxShadow: [
             BoxShadow(
               color: Colors.black.withValues(alpha: 0.05),
               blurRadius: 4,
               offset: const Offset(0, 2),
             ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  // Step 4: Interests
  Widget _buildInterestsStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildTitle("Your passions", "Pick at least 3 things you love."),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _interests.map((interest) {
                final isSelected = _selectedInterests.contains(interest.id);
                return GestureDetector(
                  onTap: () {
                    _haptic();
                    setState(() {
                      if (isSelected) {
                        _selectedInterests.remove(interest.id);
                      } else {
                        if (_selectedInterests.length < 5) {
                           _selectedInterests.add(interest.id);
                        }
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? FreezmeColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected ? FreezmeColors.primary : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(interest.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          interest.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // Step 4: Photos (New)
  Widget _buildPhotosStep() {
    final controller = AppFlowScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildTitle("Add your best photos", "Upload at least 2 photos to continue."),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: 6,
              itemBuilder: (ctx, index) {
                if (index >= controller.photoSlots.length) return const SizedBox();
                final slot = controller.photoSlots[index];
                return GestureDetector(
                  onTap: () async {
                    _haptic();
                    try {
                      await controller.uploadPhotoForSlot(index);
                      // Force rebuild to check _canProceed
                      setState(() {});
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to upload photo: $e')),
                        );
                      }
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: slot.imageUrl != null ? FreezmeColors.primary : Colors.grey.shade300,
                        width: slot.imageUrl != null ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                         if (slot.localPath != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(slot.localPath!), fit: BoxFit.cover),
                          )
                        else if (slot.imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: slot.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: Colors.grey.shade200),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                            ),
                          )
                        else if (slot.status == PhotoSlotStatus.uploading)
                          const Center(child: CircularProgressIndicator())
                        else
                          const Icon(Icons.add_a_photo_rounded, color: Colors.grey),
                          
                        if (slot.imageUrl != null)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: FreezmeColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, color: Colors.white, size: 12),
                            ),
                          ),
                         
                        // Number indicator
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: slot.imageUrl != null ? Colors.white : Colors.grey.shade400,
                              shadows: slot.imageUrl != null ? [
                                const Shadow(blurRadius: 4, color: Colors.black54),
                              ] : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Step 5: Bio (New)
  Widget _buildBioStep() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(child: _buildTitle("Written Bio", "Tell us a bit about yourself.")),
            const SizedBox(height: 24),
      
            // AI Generator Button
            Center(
              child: OutlinedButton.icon(
                onPressed: _isGeneratingBio ? null : _generateAiBio,
                icon: _isGeneratingBio 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 18),
                label: Text(_isGeneratingBio ? "Writing..." : "Generate with AI"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FreezmeColors.primary,
                  side: const BorderSide(color: FreezmeColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 16),
      
            // Prompts
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _bioPrompts.map((prompt) {
                return ActionChip(
                  label: Text(prompt, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  onPressed: () {
                    final currentText = _bioController.text;
                    final newText = (currentText.isNotEmpty && !currentText.endsWith(' ') && !currentText.endsWith('\n'))
                        ? '$currentText\n\n$prompt '
                        : '$currentText$prompt ';
                    
                    _bioController.text = newText;
                    // Move cursor to end
                    _bioController.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
      
            // Text Area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _bioController,
                maxLines: 6,
                maxLength: 150,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 16, height: 1.4),
                decoration: InputDecoration(
                  hintText: "Start typing or pick a prompt...",
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: InputBorder.none,
                  counterText: "",
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_bio.length}/150',
                style: TextStyle(
                  color: _bio.length >= 10 ? FreezmeColors.success : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 40), // Bottom padding
          ],
        ),
      ),
    );
  }

  Future<void> _generateAiBio() async {
    setState(() => _isGeneratingBio = true);
    
    // Simulate Backend AI Call
    await Future.delayed(const Duration(seconds: 2));
    
    // Mock Logic based on state
    final interests = _selectedInterests.take(3).toList();
    
    String interestStr = interests.isNotEmpty ? "I love ${interests.join(', ')}." : "I love trying new things.";
    
    // Simple template generator
    final templates = [
      "Running on caffeine and $interestStr Swipe right if you're into spontaneous trips!",
      "$interestStr Looking for someone to share good vibes and better food.",
      "Professional over-thinker. $interestStr Let's skip the small talk.",
    ];
    
    setState(() {
      _bioController.text = templates[DateTime.now().millisecond % templates.length];
      _isGeneratingBio = false;
    });
  }

  // Step 6: Looking For
  Widget _buildLookingForStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildTitle("Relationship Goals", "What are you looking for right now?"),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _lookingForOptions.length,
            itemBuilder: (context, index) {
              final option = _lookingForOptions[index];
              final isSelected = _lookingFor.contains(option.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TappableCard(
                  onTap: () {
                    setState(() {
                      _lookingFor.clear(); // Single select usually, but let's keep list logic
                      _lookingFor.add(option.id);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isSelected ? FreezmeColors.primary.withValues(alpha: 0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? FreezmeColors.primary : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(option.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.label,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                option.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: FreezmeColors.primary),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Step 7: Vibe Type
  Widget _buildVibeTypeStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildTitle("What's your vibe?", "Helps us match your energy."),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
             padding: const EdgeInsets.symmetric(horizontal: 24),
             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
               crossAxisCount: 2,
               crossAxisSpacing: 12,
               mainAxisSpacing: 12,
               childAspectRatio: 0.85,
             ),
             itemCount: _vibeTypes.length,
             itemBuilder: (context, index) {
               final vibe = _vibeTypes[index];
               final isSelected = _vibeType == vibe.id;
               return GestureDetector(
                 onTap: () {
                   _haptic();
                   setState(() => _vibeType = vibe.id);
                 },
                 child: Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                     color: isSelected ? FreezmeColors.primary : Colors.white,
                     borderRadius: BorderRadius.circular(20),
                     border: Border.all(
                       color: isSelected ? FreezmeColors.primary : Colors.grey.shade200,
                     ),
                     boxShadow: [
                       BoxShadow(
                         color: Colors.black.withValues(alpha: 0.05),
                         blurRadius: 8,
                         offset: const Offset(0, 4),
                       ),
                     ],
                   ),
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Text(vibe.emoji, style: const TextStyle(fontSize: 40)),
                       const SizedBox(height: 16),
                       Text(
                         vibe.label,
                         textAlign: TextAlign.center,
                         style: TextStyle(
                           fontSize: 16,
                           fontWeight: FontWeight.bold,
                           color: isSelected ? Colors.white : Colors.black87,
                         ),
                       ),
                       const SizedBox(height: 8),
                       Text(
                         vibe.description,
                         textAlign: TextAlign.center,
                         style: TextStyle(
                           fontSize: 12,
                           color: isSelected ? Colors.white70 : Colors.grey.shade500,
                         ),
                       ),
                     ],
                   ),
                 ),
               );
             },
          ),
        ),
      ],
    );
  }
}

class _InterestItem {
  final String id;
  final String emoji;
  final String label;
  const _InterestItem(this.id, this.emoji, this.label);
}

class _LookingForItem {
  final String id;
  final String emoji;
  final String label;
  final String description;
  const _LookingForItem(this.id, this.emoji, this.label, this.description);
}

class _VibeTypeItem {
  final String id;
  final String emoji;
  final String label;
  final String description;
  const _VibeTypeItem(this.id, this.emoji, this.label, this.description);
}
