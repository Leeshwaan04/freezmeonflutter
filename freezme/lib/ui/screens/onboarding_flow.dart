import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../../services/archetype_service.dart';
import '../widgets/freezme_logo.dart';
import '../../core/app_stage.dart';
import '../../models/blueprint.dart';

class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage> {
  int _step = 1;
  static const int _totalSteps = 6;
  bool _showArchetypeResult = false;

  // Step 1: Intent
  DatingIntent? _selectedIntent;
  bool _ageConfirmed = false;

  // Step 2: Personality Traits
  final List<PersonalityTrait> _selectedTraits = [];

  // Step 3: Lifestyle Factors
  final List<LifestyleFactor> _selectedLifestyle = [];

  // Step 4: Interests
  final List<String> _selectedInterests = [];

  // Step 5: Voice Intro

  // Step 6: Profile
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final List<File?> _photos = [null, null];

  void _handleNext(AppFlowController flow) {
    if (_step == _totalSteps) {
      if (!_showArchetypeResult) {
        flow.updateOnboardingData(
          bio: _bioController.text,
          age: int.tryParse(_ageController.text),
          interests: _selectedInterests,
          intent: _selectedIntent,
          personalityTraits: List.from(_selectedTraits),
          lifestyleFactors: List.from(_selectedLifestyle),
        );
        setState(() => _showArchetypeResult = true);
        return;
      }
      
      // After archetype review, go home
      flow.isVerified = true; 
      flow.replaceStack([AppStage.dailyPool]); 
      return;
    }

    setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final progress = _step / _totalSteps;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (!_showArchetypeResult)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FreezmeLogo(size: LogoSize.sm, showText: true),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: FreezmeColors.surfaceAlt,
                          valueColor: const AlwaysStoppedAnimation<Color>(FreezmeColors.primary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Step $_step of $_totalSteps', style: FreezmeTypography.bodyMuted),
                    ],
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _showArchetypeResult ? _buildArchetypeResult(flow) : _buildStep(context, flow),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    if (_step > 1 && !_showArchetypeResult)
                      IconButton.outlined(
                        onPressed: () => setState(() => _step--),
                        icon: const Icon(Icons.chevron_left),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _canProceed() ? () => _handleNext(flow) : null,
                        style: FreezmeButtons.primaryFilled,
                        child: Text(_showArchetypeResult ? 'Let\'s Go!' : (_step == _totalSteps ? 'Finalize' : 'Continue')),
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

  bool _canProceed() {
    switch (_step) {
      case 1: return _selectedIntent != null && _ageConfirmed;
      case 2: return _selectedTraits.isNotEmpty;
      case 3: return _selectedLifestyle.isNotEmpty;
      case 4: return _selectedInterests.length >= 3;
      case 5: return true; // Voice intro is optional for now
      case 6: return _bioController.text.length > 5 && _ageController.text.isNotEmpty;
      default: return false;
    }
  }

  Widget _buildStep(BuildContext context, AppFlowController flow) {
    switch (_step) {
      case 1: return _buildIntentStep();
      case 2: return _buildPersonalityStep();
      case 3: return _buildLifestyleStep();
      case 4: return _buildInterestsStep();
      case 5: return _buildVoiceStep();
      case 6: return _buildProfileStep();
      default: return const SizedBox();
    }
  }

  Widget _buildIntentStep() {
    return SingleChildScrollView(
      key: const ValueKey(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('What are you looking for?', style: FreezmeTypography.h1),
          const SizedBox(height: 12),
          const Text('Be honest. We use this to match you with like-minded people.', style: FreezmeTypography.body),
          const SizedBox(height: 24),
          if (_selectedIntent != null)
             _InsightBanner(
               text: _selectedIntent == DatingIntent.meaningful
                 ? "Beautiful. Most Freezme users are here for intentional dating."
                 : "Great! Let's find some interesting people for you.",
             ),
          const SizedBox(height: 16),
          ...DatingIntent.values.map((intent) {
            final isSelected = _selectedIntent == intent;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => setState(() => _selectedIntent = intent),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected ? FreezmeColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? FreezmeColors.primary : FreezmeColors.border),
                  ),
                  child: Row(
                    children: [
                      Text(
                        intent == DatingIntent.meaningful ? '💜' : (intent == DatingIntent.exploring ? '✨' : '🤝'),
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        intent.name.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : FreezmeColors.neutral,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _ageConfirmed,
                onChanged: (v) => setState(() => _ageConfirmed = v ?? false),
                activeColor: FreezmeColors.primary,
              ),
              const Expanded(child: Text('I confirm I am over 18 years old.')),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPersonalityStep() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('Describe your vibe', style: FreezmeTypography.h1),
        const SizedBox(height: 12),
        const Text('Choose traits that best describe you.', style: FreezmeTypography.body),
        const SizedBox(height: 24),
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: PersonalityTrait.values.map((trait) {
              final isSelected = _selectedTraits.contains(trait);
              return FilterChip(
                label: Text(trait.name),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedTraits.add(trait);
                    } else {
                      _selectedTraits.remove(trait);
                    }
                  });
                },
                selectedColor: FreezmeColors.primary,
                labelStyle: TextStyle(color: isSelected ? Colors.white : FreezmeColors.neutral),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLifestyleStep() {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('Your Lifestyle', style: FreezmeTypography.h1),
        const SizedBox(height: 24),
        Expanded(
          child: ListView(
            children: LifestyleFactor.values.map((f) {
               final isSelected = _selectedLifestyle.contains(f);
               return CheckboxListTile(
                 title: Text(f.name.toUpperCase()),
                 value: isSelected,
                 onChanged: (v) {
                   setState(() {
                     if (v!) {
                       _selectedLifestyle.add(f);
                     } else {
                       _selectedLifestyle.remove(f);
                     }
                   });
                 },
                 activeColor: FreezmeColors.primary,
               );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInterestsStep() {
    final List<String> available = ['Music', 'Art', 'Coffee', 'Travel', 'Gaming', 'Fitness', 'Movies', 'Books'];
    return Column(
      key: const ValueKey(4),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text('Passions', style: FreezmeTypography.h1),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: available.map((interest) {
            final isSelected = _selectedInterests.contains(interest);
            return ActionChip(
              label: Text(interest),
              backgroundColor: isSelected ? FreezmeColors.primary : Colors.white,
              labelStyle: TextStyle(color: isSelected ? Colors.white : FreezmeColors.neutral),
              onPressed: () {
                setState(() {
                  if (isSelected) {
                    _selectedInterests.remove(interest);
                  } else {
                    _selectedInterests.add(interest);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVoiceStep() {
    return Column(
      key: const ValueKey(5),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.mic, size: 80, color: FreezmeColors.primary),
        const SizedBox(height: 24),
        const Text('Voice Introduction', style: FreezmeTypography.h1),
        const SizedBox(height: 12),
        const Text('Add a 15-second voice clip. Voices create 3x more meaningful matches.', textAlign: TextAlign.center, style: FreezmeTypography.body),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () {}, 
          icon: const Icon(Icons.play_arrow),
          label: const Text('Record Introduction'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: FreezmeColors.primary,
            minimumSize: const Size(200, 50),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStep() {
    return SingleChildScrollView(
      key: const ValueKey(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('Almost there!', style: FreezmeTypography.h1),
          const SizedBox(height: 32),
          TextField(
            controller: _ageController,
            decoration: const InputDecoration(labelText: 'Age', hintText: 'How old are you?'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _bioController,
            decoration: const InputDecoration(labelText: 'Bio', hintText: 'Write a quick introduction...'),
            maxLines: 3,
          ),
          const SizedBox(height: 40),
          const Text('Top Profile Photos', style: FreezmeTypography.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPhotoSlot(0),
              const SizedBox(width: 12),
              _buildPhotoSlot(1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSlot(int index) {
    final file = _photos[index];
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (picked != null && mounted) {
          setState(() => _photos[index] = File(picked.path));
        }
      },
      child: Container(
        width: 100,
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? FreezmeColors.primary : FreezmeColors.border,
            width: file != null ? 2 : 1,
          ),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(file, fit: BoxFit.cover),
              )
            : const Icon(Icons.add_a_photo, color: FreezmeColors.muted),
      ),
    );
  }
  Widget _buildArchetypeResult(AppFlowController flow) {
    final archetype = flow.userArchetype;
    final traits = flow.userBlueprint?.personalityTraits ?? [];
    final lifestyle = flow.userBlueprint?.lifestyleFactors ?? [];

    final archetypeEmoji = switch (archetype) {
      PersonalityArchetype.explorer   => '🌍',
      PersonalityArchetype.nurturer   => '💛',
      PersonalityArchetype.visionary  => '🔮',
      PersonalityArchetype.harmonizer => '☮️',
      PersonalityArchetype.dynamo     => '⚡',
      null                            => '✨',
    };

    final keywordBadges = <String>[
      ...traits.map((t) => t.name[0].toUpperCase() + t.name.substring(1)),
      ...lifestyle.map((l) => l.name[0].toUpperCase() + l.name.substring(1)),
    ];

    return SingleChildScrollView(
      key: const ValueKey('archetype'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          // Top label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: FreezmeColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: FreezmeColors.primary.withValues(alpha: 0.25)),
            ),
            child: const Text(
              'YOUR DATING PERSONALITY',
              style: TextStyle(letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.bold, color: FreezmeColors.primary),
            ),
          ),
          const SizedBox(height: 28),
          // Big emoji in gradient circle
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: FreezmeGradients.primary,
            ),
            child: Center(
              child: Text(archetypeEmoji, style: const TextStyle(fontSize: 44)),
            ),
          ),
          const SizedBox(height: 20),
          // Archetype name
          Text(
            archetype?.label ?? 'The Adventurer',
            style: FreezmeTypography.h1.copyWith(fontSize: 34),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Description card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: FreezmeColors.border),
              boxShadow: [
                BoxShadow(color: FreezmeColors.primary.withValues(alpha: 0.07), blurRadius: 24, offset: const Offset(0, 10)),
              ],
            ),
            child: Text(
              archetype?.description ?? 'You are a blend of curiosity and passion.',
              textAlign: TextAlign.center,
              style: FreezmeTypography.bodyLarge,
            ),
          ),
          if (keywordBadges.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('YOUR TRAITS', style: TextStyle(letterSpacing: 1.5, fontSize: 11, fontWeight: FontWeight.bold, color: FreezmeColors.muted)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keywordBadges.map((badge) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2FF7), Color(0xFF4A90D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(badge, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              )).toList(),
            ),
          ],
          const SizedBox(height: 28),
          // Bottom confirmation row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FreezmeColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: FreezmeColors.primary, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Your daily pool is now curated to match your vibe.',
                    style: TextStyle(color: FreezmeColors.primary, fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _InsightBanner extends StatelessWidget {
  final String text;
  const _InsightBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FreezmeColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FreezmeColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: FreezmeColors.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: FreezmeColors.primary, fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
