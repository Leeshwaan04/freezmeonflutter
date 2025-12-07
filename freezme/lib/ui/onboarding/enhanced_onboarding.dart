import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../../main.dart';

/// Premium 6-Step Onboarding Flow
class EnhancedOnboardingFlow extends StatefulWidget {
  const EnhancedOnboardingFlow({super.key});

  @override
  State<EnhancedOnboardingFlow> createState() => _EnhancedOnboardingFlowState();
}

class _EnhancedOnboardingFlowState extends State<EnhancedOnboardingFlow>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 6;

  // Animation controllers
  late AnimationController _progressController;
  late AnimationController _fadeController;

  // Collected data
  String _name = '';
  DateTime? _birthDate;
  String? _gender;
  final List<String> _selectedInterests = [];
  final List<String> _lookingFor = [];
  String? _vibeType;
  final List<File> _photos = [];
  int _minAge = 18;
  int _maxAge = 50;
  int _maxDistance = 50;

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

  @override
  void initState() {
    super.initState();
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

  void _completeOnboarding() {
    _heavyHaptic();
    final controller = AppFlowScope.of(context);
    controller.saveOnboardingProgress(
      name: _name,
      age: _birthDate != null
          ? DateTime.now().difference(_birthDate!).inDays ~/ 365
          : null,
      interests: _selectedInterests,
    );
    controller.completeOnboarding();
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0: return true;
      case 1: return _name.length >= 2;
      case 2: return _birthDate != null;
      case 3: return _selectedInterests.length >= 3;
      case 4: return _lookingFor.isNotEmpty;
      case 5: return _vibeType != null;
      default: return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF5F8), Color(0xFFF5E6F0)],
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
                    _buildWelcomeStep(),
                    _buildNameStep(),
                    _buildBirthdayStep(),
                    _buildInterestsStep(),
                    _buildLookingForStep(),
                    _buildVibeTypeStep(),
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
      padding: const EdgeInsets.all(20),
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back, color: FreezmeColors.primary),
                  ),
                )
              else
                const SizedBox(width: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: FreezmeColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentStep + 1} / $_totalSteps',
                  style: const TextStyle(
                    color: FreezmeColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _currentStep == _totalSteps - 1 ? null : _completeOnboarding,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: _currentStep == _totalSteps - 1
                        ? Colors.transparent
                        : FreezmeColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          Row(
            children: List.generate(_totalSteps, (index) {
              final isActive = index == _currentStep;
              final isCompleted = index < _currentStep;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 4,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? FreezmeColors.primary
                        : isActive
                            ? FreezmeColors.primary.withValues(alpha: 0.5)
                            : FreezmeColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Container(
          decoration: BoxDecoration(
            gradient: _canProceed()
                ? const LinearGradient(
                    colors: [FreezmeColors.primary, Color(0xFF8B5CF6)],
                  )
                : null,
            color: _canProceed() ? null : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(28),
            boxShadow: _canProceed()
                ? [
                    BoxShadow(
                      color: FreezmeColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: FilledButton(
            onPressed: _canProceed() ? _nextStep : null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor: Colors.grey.shade500,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _currentStep == _totalSteps - 1 ? "Let's Go!" : 'Continue',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_currentStep == _totalSteps - 1) ...[
                  const SizedBox(width: 8),
                  const Text('🚀', style: TextStyle(fontSize: 20)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Step 1: Welcome
  Widget _buildWelcomeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [FreezmeColors.primary, Color(0xFF8B5CF6)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: FreezmeColors.primary.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.ac_unit_rounded, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 32),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [FreezmeColors.primary, Color(0xFF8B5CF6)],
            ).createShader(bounds),
            child: const Text(
              "Let's Set You Up",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Just a few steps to find your\nperfect match tonight",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          _buildWelcomeFeature(
            Icons.bolt_rounded,
            'Quick Setup',
            'Less than 2 minutes to complete',
          ),
          const SizedBox(height: 16),
          _buildWelcomeFeature(
            Icons.favorite_rounded,
            'Smart Matching',
            'Find people who share your interests',
          ),
          const SizedBox(height: 16),
          _buildWelcomeFeature(
            Icons.verified_user_rounded,
            'Safe & Private',
            'Your data is always protected',
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeFeature(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FreezmeColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: FreezmeColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Step 2: Name
  Widget _buildNameStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👋', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 24),
          const Text(
            "What's your name?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: FreezmeColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "This is how you'll appear to others",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) => setState(() => _name = value),
              textCapitalization: TextCapitalization.words,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Your first name',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                contentPadding: const EdgeInsets.all(24),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_name.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Nice to meet you, $_name! 😊',
              style: const TextStyle(
                fontSize: 16,
                color: FreezmeColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Step 3: Birthday
  Widget _buildBirthdayStep() {
    final age = _birthDate != null
        ? DateTime.now().difference(_birthDate!).inDays ~/ 365
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎂', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 24),
          const Text(
            "When's your birthday?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: FreezmeColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You must be 18+ to use Freezme",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 40),
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
                      colorScheme: const ColorScheme.light(
                        primary: FreezmeColors.primary,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                setState(() => _birthDate = date);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _birthDate != null
                      ? FreezmeColors.primary
                      : Colors.grey.shade300,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: _birthDate != null
                        ? FreezmeColors.primary
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _birthDate != null
                        ? '${_birthDate!.month}/${_birthDate!.day}/${_birthDate!.year}'
                        : 'Tap to select date',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _birthDate != null
                          ? FreezmeColors.primary
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (age != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: FreezmeColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "You're $age years old 🎉",
                style: const TextStyle(
                  fontSize: 16,
                  color: FreezmeColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
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
              const Text(
                "What are you into?",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: FreezmeColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Pick at least 3 interests (${_selectedInterests.length} selected)",
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
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
                        _selectedInterests.add(interest.id);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? FreezmeColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: isSelected
                            ? FreezmeColors.primary
                            : Colors.grey.shade300,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: FreezmeColors.primary.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
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

  // Step 5: Looking For
  Widget _buildLookingForStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            "What are you looking for?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: FreezmeColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Select all that apply",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.builder(
              itemCount: _lookingForOptions.length,
              itemBuilder: (context, index) {
                final option = _lookingForOptions[index];
                final isSelected = _lookingFor.contains(option.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      _haptic();
                      setState(() {
                        if (isSelected) {
                          _lookingFor.remove(option.id);
                        } else {
                          _lookingFor.add(option.id);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? FreezmeColors.primary.withValues(alpha: 0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? FreezmeColors.primary
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(option.emoji, style: const TextStyle(fontSize: 32)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.label,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? FreezmeColors.primary
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  option.description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: FreezmeColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                        ],
                      ),
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

  // Step 6: Vibe Type
  Widget _buildVibeTypeStep() {
    final vibeTypes = [
      ('introvert', '🌙', 'Introvert', 'Cozy nights & deep conversations'),
      ('ambivert', '⚖️', 'Ambivert', 'Best of both worlds'),
      ('extrovert', '🎉', 'Extrovert', 'Life of the party'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            "What's your vibe?",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: FreezmeColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "This helps us find compatible people",
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 40),
          ...vibeTypes.map((vibe) {
            final isSelected = _vibeType == vibe.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () {
                  _haptic();
                  setState(() => _vibeType = vibe.$1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [FreezmeColors.primary, Color(0xFF8B5CF6)],
                          )
                        : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? FreezmeColors.primary.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.05),
                        blurRadius: isSelected ? 15 : 10,
                        offset: Offset(0, isSelected ? 5 : 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(vibe.$2, style: const TextStyle(fontSize: 36)),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vibe.$3,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : FreezmeColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vibe.$4,
                              style: TextStyle(
                                fontSize: 14,
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : Colors.grey.shade600,
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
          }),
        ],
      ),
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
