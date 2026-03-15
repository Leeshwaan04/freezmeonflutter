import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../widgets/freezme_logo.dart';
import '../../core/app_stage.dart';

class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage> {
  int _step = 1;
  String? _selectedIntent;
  bool _ageConfirmed = false;
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final List<String> _selectedInterests = [];

  final List<({String id, String label, String emoji})> _intents = const [
    (id: 'meaningful', label: 'Meaningful connection', emoji: '💜'),
    (id: 'exploring', label: 'Just exploring', emoji: '✨'),
    (id: 'see', label: 'Let\'s see where it goes', emoji: '🌟'),
  ];

  final List<({LifestyleArchetype id, String label, String emoji, String subtitle})> _missions = const [
    (id: LifestyleArchetype.gym, label: 'Gym & Sports', emoji: '🏋️', subtitle: 'Find a workout partner'),
    (id: LifestyleArchetype.brunch, label: 'Brunch & Cafe', emoji: '🥂', subtitle: 'Coffee or aesthetic eats'),
    (id: LifestyleArchetype.clubbing, label: 'Nightlife & Clubs', emoji: '🎶', subtitle: 'Dance the night away'),
    (id: LifestyleArchetype.travel, label: 'Travel & Trips', emoji: '🎒', subtitle: 'Weekend getaways'),
    (id: LifestyleArchetype.homebody, label: 'Cozy & Homey', emoji: '🏠', subtitle: 'Netflix & deep talks'),
  ];

  void _handleNext(AppFlowController flow) {
    if (_step == 4) {
      flow.updateOnboardingData(
        bio: _bioController.text,
        age: int.tryParse(_ageController.text),
        interests: _selectedInterests,
      );
      flow.beginCompatibilityQuiz();
      return;
    }

    // Sync current step data
    if (_step == 1) {
      flow.updateOnboardingData(interests: [_selectedIntent!]); // Store intent as a starting interest
    } else if (_step == 2) {
      flow.updateOnboardingData(archetype: flow.selectedArchetype);
    }

    setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final progress = _step / 4;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FreezmeInsets.pageGutter,
                  FreezmeInsets.sectionSpacing,
                  FreezmeInsets.pageGutter,
                  FreezmeInsets.sectionSpacing / 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FreezmeLogo(size: LogoSize.sm, showText: true),
                    const SizedBox(height: FreezmeInsets.elementSpacing),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: FreezmeColors.surfaceAlt,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          FreezmeColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: FreezmeInsets.elementSpacing / 1.5),
                    Text(
                      'Step $_step of 4',
                      style: FreezmeTypography.bodyMuted,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FreezmeInsets.pageGutter,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildStep(context, flow),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FreezmeInsets.pageGutter,
                  FreezmeInsets.sectionSpacing / 1.5,
                  FreezmeInsets.pageGutter,
                  FreezmeInsets.sectionSpacing,
                ),
                child: Row(
                  children: [
                    if (_step > 1)
                      OutlinedButton(
                        onPressed: () => setState(() => _step--),
                        style: FreezmeButtons.secondaryOutlined,
                        child: const Icon(Icons.chevron_left),
                      )
                    else
                      const SizedBox(width: 0, height: 0),
                    const SizedBox(width: FreezmeInsets.elementSpacing / 1.5),
                    Expanded(
                      child: FilledButton(
                        onPressed: (_step == 1 && (_selectedIntent == null || !_ageConfirmed)) ||
                                (_step == 2 && flow.selectedArchetype == null)
                            ? null
                            : () => _handleNext(flow),
                        style: FreezmeButtons.primaryFilled,
                        child: Text(_step == 4 ? 'Continue' : 'Next'),
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

  Widget _buildStep(BuildContext context, AppFlowController flow) {
    switch (_step) {
      case 1:
        return Column(
          key: const ValueKey<int>(1),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: FreezmeInsets.elementSpacing),
            Center(
              child: Column(
                children: [
                  Text(
                    'What brings you here?',
                    style: FreezmeTypography.title.copyWith(
                      color: FreezmeColors.primary,
                    ),
                  ),
                  const SizedBox(height: FreezmeInsets.elementSpacing / 2),
                  const Text(
                    'Choose what feels right 💫',
                    style: FreezmeTypography.bodyMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: FreezmeInsets.sectionSpacing),
            for (int i = 0; i < _intents.length; i++) ...[
              _StaggeredEntrance(
                index: i,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedIntent = _intents[i].id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(
                      bottom: FreezmeInsets.elementSpacing,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: FreezmeInsets.elementSpacing,
                      vertical: FreezmeInsets.sectionSpacing / 1.5,
                    ),
                    transform: Matrix4.identity()
                      ..scale(_selectedIntent == _intents[i].id ? 1.02 : 1.0),
                    decoration: BoxDecoration(
                      color: _selectedIntent == _intents[i].id
                          ? FreezmeColors.primary
                          : Colors.white,
                      borderRadius:
                          BorderRadius.circular(FreezmeInsets.cardRadius),
                      boxShadow: _selectedIntent == _intents[i].id
                          ? [
                              BoxShadow(
                                color: FreezmeColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              )
                            ]
                          : null,
                      border: Border.all(
                        color: _selectedIntent == _intents[i].id
                            ? FreezmeColors.primary
                            : FreezmeColors.border,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(_intents[i].emoji, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: FreezmeInsets.elementSpacing),
                        Expanded(
                          child: Text(
                            _intents[i].label,
                            style: TextStyle(
                              color: _selectedIntent == _intents[i].id
                                  ? Colors.white
                                  : FreezmeColors.neutral,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: FreezmeInsets.elementSpacing),
            GestureDetector(
              onTap: () => setState(() => _ageConfirmed = !_ageConfirmed),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 22,
                    width: 22,
                    decoration: BoxDecoration(
                      color: _ageConfirmed ? FreezmeColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _ageConfirmed ? FreezmeColors.primary : FreezmeColors.border,
                        width: 2,
                      ),
                    ),
                    child: _ageConfirmed
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'I confirm I am 18 years or older',
                      style: TextStyle(
                        fontSize: 14,
                        color: FreezmeColors.neutral,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case 2:
        return _buildArchetypeStep(context, flow);
      case 3:
        return Column(
          key: const ValueKey<int>(3),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: FreezmeInsets.elementSpacing),
            Center(
              child: Column(
                children: [
                  Text(
                    'Show your vibe',
                    style: FreezmeTypography.title.copyWith(
                      color: FreezmeColors.primary,
                    ),
                  ),
                  const SizedBox(height: FreezmeInsets.elementSpacing / 2),
                  const Text(
                    'Add at least 3 photos 📸',
                    style: FreezmeTypography.bodyMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: FreezmeInsets.sectionSpacing),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: FreezmeInsets.elementSpacing,
                mainAxisSpacing: FreezmeInsets.elementSpacing,
                children: List.generate(
                  6,
                  (index) => Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(FreezmeInsets.cardRadius),
                      border: Border.all(
                        color: FreezmeColors.border,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: FreezmeColors.muted,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: FreezmeInsets.elementSpacing),
            Center(
              child: TextButton(
                onPressed: () => _handleNext(flow),
                child: const Text('Skip for now (Dev Mode)'),
              ),
            ),
          ],
        );
      case 4:
      default:
        return SingleChildScrollView(
          key: const ValueKey<int>(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: FreezmeInsets.elementSpacing),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Tell us about you',
                      style: FreezmeTypography.title.copyWith(
                        color: FreezmeColors.primary,
                      ),
                    ),
                    const SizedBox(height: FreezmeInsets.elementSpacing / 2),
                    const Text(
                      'Share your story 💜',
                      style: FreezmeTypography.bodyMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: FreezmeInsets.sectionSpacing),
              const Text(
                'Bio',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: FreezmeColors.neutral,
                ),
              ),
              const SizedBox(height: FreezmeInsets.elementSpacing / 2),
              TextField(
                controller: _bioController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'What makes you, you?',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(FreezmeInsets.cardRadius),
                    borderSide: const BorderSide(color: FreezmeColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(FreezmeInsets.cardRadius),
                    borderSide: const BorderSide(color: FreezmeColors.border),
                  ),
                ),
              ),
              const SizedBox(height: FreezmeInsets.sectionSpacing),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Age',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: FreezmeColors.neutral,
                          ),
                        ),
                        const SizedBox(
                          height: FreezmeInsets.elementSpacing / 2,
                        ),
                        TextField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '25',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                FreezmeInsets.cardRadius,
                              ),
                              borderSide:
                                  const BorderSide(color: FreezmeColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                FreezmeInsets.cardRadius,
                              ),
                              borderSide:
                                  const BorderSide(color: FreezmeColors.border),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: FreezmeInsets.elementSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Distance (km)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: FreezmeColors.neutral,
                          ),
                        ),
                        const SizedBox(
                          height: FreezmeInsets.elementSpacing / 2,
                        ),
                        TextField(
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '50',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                FreezmeInsets.cardRadius,
                              ),
                              borderSide:
                                  const BorderSide(color: FreezmeColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                FreezmeInsets.cardRadius,
                              ),
                              borderSide:
                                  const BorderSide(color: FreezmeColors.border),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FreezmeInsets.sectionSpacing),
              const Text(
                'Interests',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: FreezmeColors.neutral,
                ),
              ),
              const SizedBox(height: FreezmeInsets.elementSpacing),
              Wrap(
                spacing: FreezmeInsets.elementSpacing,
                runSpacing: FreezmeInsets.elementSpacing,
                children: [
                  'Music', 'Travel', 'Art', 'Fitness', 'Food', 'Books'
                ].map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isSelected) {
                        _selectedInterests.remove(interest);
                      } else {
                        _selectedInterests.add(interest);
                      }
                    }),
                    child: _InterestChip(
                      label: interest,
                      isSelected: isSelected,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 80),
            ],
          ),
        );
    }
  }

  Widget _buildArchetypeStep(BuildContext context, AppFlowController flow) {
    return Column(
      key: const ValueKey<int>(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: FreezmeInsets.elementSpacing),
        Center(
          child: Column(
            children: [
              Text(
                'What\'s your mission?',
                style: FreezmeTypography.title.copyWith(
                  color: FreezmeColors.primary,
                ),
              ),
              const SizedBox(height: FreezmeInsets.elementSpacing / 2),
              const Text(
                'What\'s on your agenda this week? 🗓️',
                style: FreezmeTypography.bodyMuted,
              ),
            ],
          ),
        ),
        const SizedBox(height: FreezmeInsets.sectionSpacing),
        Expanded(
          child: ListView.builder(
            itemCount: _missions.length,
            itemBuilder: (context, index) {
              final mission = _missions[index];
              final isSelected = flow.selectedArchetype == mission.id;
              return _StaggeredEntrance(
                index: index,
                child: GestureDetector(
                  onTap: () {
                    flow.setLifestyleArchetype(mission.id);
                    setState(() {});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(
                      bottom: FreezmeInsets.elementSpacing,
                    ),
                    padding: const EdgeInsets.all(FreezmeInsets.elementSpacing),
                    transform: Matrix4.identity()..scale(isSelected ? 1.02 : 1.0),
                    decoration: BoxDecoration(
                      color: isSelected ? FreezmeColors.primary : Colors.white,
                      borderRadius:
                          BorderRadius.circular(FreezmeInsets.cardRadius),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: FreezmeColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              )
                            ]
                          : null,
                      border: Border.all(
                        color: isSelected ? FreezmeColors.primary : FreezmeColors.border,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(mission.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: FreezmeInsets.elementSpacing),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mission.label,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : FreezmeColors.neutral,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                mission.subtitle,
                                style: TextStyle(
                                  color: isSelected ? Colors.white70 : FreezmeColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: Colors.white),
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
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.label, this.isSelected = false});

  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: isSelected ? FreezmeColors.primary : Colors.white,
      shape: const StadiumBorder(),
      labelStyle: FreezmeTypography.body.copyWith(
        fontWeight: FontWeight.w500,
        color: isSelected ? Colors.white : FreezmeColors.neutral,
      ),
      side: BorderSide(color: isSelected ? FreezmeColors.primary : FreezmeColors.border),
    );
  }
}
class _StaggeredEntrance extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggeredEntrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
