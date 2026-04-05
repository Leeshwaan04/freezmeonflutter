import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../widgets/freezme_logo.dart';
import '../../core/app_stage.dart';
import '../../models/blueprint.dart';

// ── Onboarding: The 5 Calibration Moments ────────────────────────────────────
//
// Moment 1 — The Pull       (forced-choice energy calibration + intent)
// Moment 2 — The Value      (one constrained open-ended prompt answer)
// Moment 3 — The Pace       (attachment/pace signal via scenario)
// Moment 4 — The Freeze     (presence window — when are you actually here?)
// Moment 5 — The Face       (name, age, photo)
//
// At the end: Archetype reveal screen → home
// ─────────────────────────────────────────────────────────────────────────────

const _kPrompts = [
  'The last time you genuinely helped someone — what did you do?',
  'The most spontaneous thing you\'ve ever done.',
  'I\'ll know it\'s going well if...',
  'My friends would describe me as...',
  'The thing I\'m most proud of that nobody gave me an award for.',
];

class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage> {
  int _step = 1;
  static const int _totalSteps = 5;
  bool _showArchetypeResult = false;

  // ── Moment 1: Pull — forced-choice calibration ──────────────────────────────
  final List<int> _calibrationChoices = []; // 0=A, 1=B per pair index
  DatingIntent? _selectedIntent;
  bool _ageConfirmed = false;

  // ── Moment 2: Value — prompt answer ─────────────────────────────────────────
  String _selectedPrompt = _kPrompts[0];
  final TextEditingController _promptAnswerController = TextEditingController();

  // ── Moment 3: Pace — scenario choice ────────────────────────────────────────
  int? _paceChoice; // index into _paceScenarios

  // ── Moment 4: Freeze — presence windows ─────────────────────────────────────
  // Store as Set<int> of hour buckets selected per day-group
  // Simplified: morning (6-12), afternoon (12-18), evening (18-23)
  final Set<String> _presenceBuckets = {'evening'}; // default: evenings

  // ── Moment 5: Face — name, age, photo ───────────────────────────────────────
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  File? _photo;

  // ── Derived fields ───────────────────────────────────────────────────────────
  EnergyType get _derivedEnergyType {
    if (_calibrationChoices.length < 4) return EnergyType.deepDiver;
    // choice[0]: social_energy  (A=deep, B=igniter)
    // choice[1]: structure      (A=planner, B=open_road)
    // choice[2]: recharge       (A=introvert, B=extrovert)
    // choice[3]: decision_style (A=logical, B=emotional)
    final social   = _calibrationChoices[0]; // 0=A=deep, 1=B=igniter
    final recharge = _calibrationChoices[2]; // 0=A=quiet, 1=B=social
    if (social == 1 && recharge == 1) return EnergyType.roomIgniter;
    if (social == 0 && recharge == 0) return EnergyType.deepDiver;
    if (social == 0 && recharge == 1) return EnergyType.quietStorm;
    return EnergyType.openRoad;
  }

  PaceSignal get _derivedPaceSignal {
    switch (_paceChoice) {
      case 0: return PaceSignal.takesTheirTime;
      case 1: return PaceSignal.movesWithInterest;
      case 2: return PaceSignal.movesWithInterest;
      case 3: return PaceSignal.quickConnector;
      default: return PaceSignal.movesWithInterest;
    }
  }

  List<PersonalityTrait> get _derivedTraits {
    final traits = <PersonalityTrait>[];
    if (_calibrationChoices.length >= 4) {
      traits.add(_calibrationChoices[2] == 0 ? PersonalityTrait.introvert : PersonalityTrait.extrovert);
      traits.add(_calibrationChoices[1] == 0 ? PersonalityTrait.planner : PersonalityTrait.spontaneous);
      traits.add(_calibrationChoices[3] == 0 ? PersonalityTrait.logical : PersonalityTrait.emotional);
      traits.add(_calibrationChoices[0] == 0 ? PersonalityTrait.cautious : PersonalityTrait.adventurous);
    }
    return traits;
  }

  List<Map<String, dynamic>> get _presenceWindowsJson {
    // Map buckets to hour ranges across all days (Mon–Sun = 0–6)
    final windows = <Map<String, dynamic>>[];
    for (int day = 0; day < 7; day++) {
      if (_presenceBuckets.contains('morning'))   windows.add({'day': day, 'startHour': 6,  'endHour': 12});
      if (_presenceBuckets.contains('afternoon')) windows.add({'day': day, 'startHour': 12, 'endHour': 18});
      if (_presenceBuckets.contains('evening'))   windows.add({'day': day, 'startHour': 18, 'endHour': 23});
    }
    return windows;
  }

  @override
  void dispose() {
    _promptAnswerController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  bool _canProceed() {
    switch (_step) {
      case 1: return _calibrationChoices.length == kCalibrationPairs.length
                  && _selectedIntent != null && _ageConfirmed;
      case 2: return _promptAnswerController.text.trim().length >= 10;
      case 3: return _paceChoice != null;
      case 4: return _presenceBuckets.isNotEmpty;
      case 5: return _nameController.text.trim().length >= 2
                  && _ageController.text.isNotEmpty
                  && _photo != null;
      default: return false;
    }
  }

  void _handleNext(AppFlowController flow) {
    if (_step == _totalSteps) {
      if (!_showArchetypeResult) {
        final traits = _derivedTraits;
        flow.updateOnboardingData(
          name: _nameController.text.trim(),
          bio: _promptAnswerController.text.trim(),
          age: int.tryParse(_ageController.text),
          interests: const [],
          intent: _selectedIntent,
          personalityTraits: traits,
          lifestyleFactors: const [],
          energyType: _derivedEnergyType,
          paceSignal: _derivedPaceSignal,
          promptAnswer: PromptAnswer(
            prompt: _selectedPrompt,
            answer: _promptAnswerController.text.trim(),
          ),
          presenceWindows: _presenceWindowsJson,
        );
        setState(() => _showArchetypeResult = true);
        return;
      }
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
        decoration: const BoxDecoration(gradient: FreezmeGradients.backgroundSoft),
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
                      Text('${_stepLabel(_step)} · $_step of $_totalSteps',
                          style: FreezmeTypography.bodyMuted),
                    ],
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: _showArchetypeResult
                        ? _buildArchetypeResult(flow)
                        : _buildStep(context, flow),
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
                        child: Text(
                          _showArchetypeResult
                              ? 'Let\'s go ❄️'
                              : (_step == _totalSteps ? 'Reveal my type' : 'Continue'),
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

  String _stepLabel(int step) {
    switch (step) {
      case 1: return 'The Pull';
      case 2: return 'The Value';
      case 3: return 'The Pace';
      case 4: return 'The Freeze';
      case 5: return 'The Face';
      default: return '';
    }
  }

  Widget _buildStep(BuildContext context, AppFlowController flow) {
    switch (_step) {
      case 1: return _buildMoment1();
      case 2: return _buildMoment2();
      case 3: return _buildMoment3();
      case 4: return _buildMoment4();
      case 5: return _buildMoment5();
      default: return const SizedBox();
    }
  }

  // ── Moment 1: The Pull ────────────────────────────────────────────────────

  Widget _buildMoment1() {
    return SingleChildScrollView(
      key: const ValueKey(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('Which pulls you more?', style: FreezmeTypography.h1),
          const SizedBox(height: 8),
          const Text(
            'There\'s no right answer. Pick what you actually feel.',
            style: FreezmeTypography.body,
          ),
          const SizedBox(height: 28),
          ...kCalibrationPairs.asMap().entries.map((entry) {
            final i = entry.key;
            final pair = entry.value;
            final chosen = _calibrationChoices.length > i ? _calibrationChoices[i] : -1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _CalibrationPairCard(
                optionA: pair.optionA,
                optionB: pair.optionB,
                chosen: chosen,
                onChoose: (choice) {
                  setState(() {
                    if (_calibrationChoices.length <= i) {
                      _calibrationChoices.add(choice);
                    } else {
                      _calibrationChoices[i] = choice;
                    }
                  });
                },
              ),
            );
          }),
          const SizedBox(height: 24),
          const Text('What are you here for?', style: FreezmeTypography.h1),
          const SizedBox(height: 12),
          const Text('We match intent — be honest.',
              style: FreezmeTypography.bodyMuted),
          const SizedBox(height: 16),
          ...DatingIntent.values.map((intent) {
            final isSelected = _selectedIntent == intent;
            final (emoji, label, sub) = switch (intent) {
              DatingIntent.meaningful => ('💜', 'Something real', 'A genuine, lasting connection'),
              DatingIntent.exploring  => ('✨', 'Open to see', 'Curious, no pressure'),
              DatingIntent.friendship => ('🤝', 'Connection first', 'Start as friends, see where it goes'),
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => setState(() => _selectedIntent = intent),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? FreezmeColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? FreezmeColors.primary : FreezmeColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : FreezmeColors.neutral,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                )),
                            Text(sub,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : FreezmeColors.muted,
                                  fontSize: 12,
                                )),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _ageConfirmed,
                onChanged: (v) => setState(() => _ageConfirmed = v ?? false),
                activeColor: FreezmeColors.primary,
              ),
              const Expanded(
                child: Text('I confirm I am 18 years or older.',
                    style: TextStyle(fontSize: 13, color: FreezmeColors.neutral)),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Moment 2: The Value ───────────────────────────────────────────────────

  Widget _buildMoment2() {
    return SingleChildScrollView(
      key: const ValueKey(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('One thing about you.', style: FreezmeTypography.h1),
          const SizedBox(height: 8),
          const Text(
            'Pick a prompt. Answer honestly in 60 words or less.\nThis will be the first thing people see.',
            style: FreezmeTypography.body,
          ),
          const SizedBox(height: 24),
          // Prompt selector
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kPrompts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final selected = _kPrompts[i] == _selectedPrompt;
                return ChoiceChip(
                  label: Text(
                    'Prompt ${i + 1}',
                    style: TextStyle(
                      color: selected ? Colors.white : FreezmeColors.neutral,
                      fontSize: 12,
                    ),
                  ),
                  selected: selected,
                  selectedColor: FreezmeColors.primary,
                  backgroundColor: Colors.white,
                  onSelected: (_) => setState(() {
                    _selectedPrompt = _kPrompts[i];
                    _promptAnswerController.clear();
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FreezmeColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FreezmeColors.primary.withValues(alpha: 0.2)),
            ),
            child: Text(
              '"$_selectedPrompt"',
              style: const TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: FreezmeColors.neutral,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptAnswerController,
            maxLines: 4,
            maxLength: 280,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Your answer...',
              hintStyle: const TextStyle(color: FreezmeColors.muted),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: FreezmeColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: FreezmeColors.primary, width: 2),
              ),
            ),
          ),
          if (_promptAnswerController.text.trim().length >= 10)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _InsightBanner(
                text: 'This will show on your profile exactly as written.',
                icon: Icons.visibility_outlined,
              ),
            ),
        ],
      ),
    );
  }

  // ── Moment 3: The Pace ────────────────────────────────────────────────────

  static const _paceScenarios = [
    (
      emoji: '⏳',
      title: 'You wait.',
      sub: 'If they\'re interested, they\'ll reach out. No need to chase.',
    ),
    (
      emoji: '💬',
      title: 'You send something light.',
      sub: 'Low pressure. Just keeping the door open.',
    ),
    (
      emoji: '👀',
      title: 'You check their profile again.',
      sub: 'Decide if you still feel it before doing anything.',
    ),
    (
      emoji: '➡️',
      title: 'You move on.',
      sub: 'If they wanted to, they would have. Your energy is valuable.',
    ),
  ];

  Widget _buildMoment3() {
    return SingleChildScrollView(
      key: const ValueKey(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('You matched with someone interesting.', style: FreezmeTypography.h1),
          const SizedBox(height: 8),
          const Text(
            "It's been 2 days. They haven't messaged. You:",
            style: FreezmeTypography.body,
          ),
          const SizedBox(height: 28),
          ..._paceScenarios.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final selected = _paceChoice == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => setState(() => _paceChoice = i),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: selected ? FreezmeColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? FreezmeColors.primary : FreezmeColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(s.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title,
                                style: TextStyle(
                                  color: selected ? Colors.white : FreezmeColors.neutral,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                )),
                            const SizedBox(height: 2),
                            Text(s.sub,
                                style: TextStyle(
                                  color: selected
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : FreezmeColors.muted,
                                  fontSize: 12,
                                )),
                          ],
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (_paceChoice != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _InsightBanner(
                text: 'We\'ll match you with people who move at a compatible pace.',
                icon: Icons.people_outline,
              ),
            ),
        ],
      ),
    );
  }

  // ── Moment 4: The Freeze ──────────────────────────────────────────────────

  Widget _buildMoment4() {
    return SingleChildScrollView(
      key: const ValueKey(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('When are you actually here?', style: FreezmeTypography.h1),
          const SizedBox(height: 8),
          const Text(
            'Not online — genuinely present. We only surface you to others during your window.',
            style: FreezmeTypography.body,
          ),
          const SizedBox(height: 28),
          _PresenceWindowPicker(
            selected: _presenceBuckets,
            onChanged: (buckets) => setState(() {
              _presenceBuckets.clear();
              _presenceBuckets.addAll(buckets);
            }),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text('❄️', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'You can always freeze — pause your profile when life gets busy. Your matches stay safe.',
                    style: TextStyle(fontSize: 13, color: FreezmeColors.neutral, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Moment 5: The Face ────────────────────────────────────────────────────

  Widget _buildMoment5() {
    return SingleChildScrollView(
      key: const ValueKey(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('Almost there.', style: FreezmeTypography.h1),
          const SizedBox(height: 8),
          const Text(
            'Add one photo of you doing something — not a posed selfie. Show your world.',
            style: FreezmeTypography.body,
          ),
          const SizedBox(height: 28),
          // Photo picker
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 180,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _photo != null ? FreezmeColors.primary : FreezmeColors.border,
                    width: _photo != null ? 2 : 1,
                  ),
                  boxShadow: _photo != null
                      ? [BoxShadow(
                          color: FreezmeColors.primary.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        )]
                      : null,
                ),
                child: _photo != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Image.file(_photo!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo_outlined,
                              size: 48, color: FreezmeColors.muted),
                          SizedBox(height: 12),
                          Text('Add a photo',
                              style: TextStyle(color: FreezmeColors.muted, fontSize: 14)),
                          SizedBox(height: 4),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'You doing something you love',
                              style: TextStyle(color: FreezmeColors.muted, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'First name',
              hintText: 'What do people call you?',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: FreezmeColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Age',
              hintText: 'How old are you?',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: FreezmeColors.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _photo = File(picked.path));
    }
  }

  // ── Archetype Result ──────────────────────────────────────────────────────

  Widget _buildArchetypeResult(AppFlowController flow) {
    final energy = _derivedEnergyType;
    final paceSignal = _derivedPaceSignal;
    final traits = _derivedTraits;

    return SingleChildScrollView(
      key: const ValueKey('archetype'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: FreezmeColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: FreezmeColors.primary.withValues(alpha: 0.25)),
            ),
            child: const Text(
              'YOUR ENERGY TYPE',
              style: TextStyle(
                letterSpacing: 2, fontSize: 11,
                fontWeight: FontWeight.bold, color: FreezmeColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            width: 100, height: 100,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: FreezmeGradients.primary,
            ),
            child: Center(
              child: Text(energy.emoji, style: const TextStyle(fontSize: 44)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            energy.label,
            style: FreezmeTypography.h1.copyWith(fontSize: 32),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            paceSignal.label,
            style: const TextStyle(
              color: FreezmeColors.muted, fontSize: 14, letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: FreezmeColors.border),
              boxShadow: [
                BoxShadow(
                  color: FreezmeColors.primary.withValues(alpha: 0.07),
                  blurRadius: 24, offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Text(
              energy.description,
              textAlign: TextAlign.center,
              style: FreezmeTypography.bodyLarge,
            ),
          ),
          const SizedBox(height: 24),
          // Prompt answer preview
          if (_promptAnswerController.text.trim().isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('YOUR ANSWER', style: TextStyle(
                letterSpacing: 1.5, fontSize: 11,
                fontWeight: FontWeight.bold, color: FreezmeColors.muted,
              )),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FreezmeColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"$_selectedPrompt"',
                    style: const TextStyle(
                      fontSize: 12, color: FreezmeColors.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _promptAnswerController.text.trim(),
                    style: const TextStyle(fontSize: 15, color: FreezmeColors.neutral, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Trait badges
          if (traits.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('YOUR TRAITS', style: TextStyle(
                letterSpacing: 1.5, fontSize: 11,
                fontWeight: FontWeight.bold, color: FreezmeColors.muted,
              )),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: traits.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B2FF7), Color(0xFF4A90D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  t.name[0].toUpperCase() + t.name.substring(1),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FreezmeColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: const [
                Icon(Icons.auto_awesome, color: FreezmeColors.primary, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your pool is now calibrated to your energy. Freeze Rooms open daily.',
                    style: TextStyle(
                      color: FreezmeColors.primary, fontWeight: FontWeight.w500, fontSize: 14,
                    ),
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

// ── Calibration pair card ─────────────────────────────────────────────────────

class _CalibrationPairCard extends StatelessWidget {
  const _CalibrationPairCard({
    required this.optionA,
    required this.optionB,
    required this.chosen,
    required this.onChoose,
  });

  final String optionA;
  final String optionB;
  final int chosen; // -1 = none, 0 = A, 1 = B
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _OptionCard(label: optionA, selected: chosen == 0, onTap: () => onChoose(0))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'or',
            style: TextStyle(
              color: FreezmeColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: _OptionCard(label: optionB, selected: chosen == 1, onTap: () => onChoose(1))),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? FreezmeColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? FreezmeColors.primary : FreezmeColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : FreezmeColors.neutral,
            fontSize: 12,
            height: 1.4,
          ),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ── Presence window picker ────────────────────────────────────────────────────

class _PresenceWindowPicker extends StatefulWidget {
  const _PresenceWindowPicker({
    required this.selected,
    required this.onChanged,
  });
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_PresenceWindowPicker> createState() => _PresenceWindowPickerState();
}

class _PresenceWindowPickerState extends State<_PresenceWindowPicker> {
  static const _buckets = [
    (key: 'morning',   emoji: '🌅', label: 'Mornings',   sub: '6am – 12pm'),
    (key: 'afternoon', emoji: '☀️', label: 'Afternoons', sub: '12pm – 6pm'),
    (key: 'evening',   emoji: '🌙', label: 'Evenings',   sub: '6pm – 11pm'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _buckets.map((b) {
        final selected = widget.selected.contains(b.key);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              final next = Set<String>.from(widget.selected);
              if (selected) {
                if (next.length > 1) next.remove(b.key); // keep at least one
              } else {
                next.add(b.key);
              }
              widget.onChanged(next);
            },
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: selected ? FreezmeColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? FreezmeColors.primary : FreezmeColors.border,
                ),
              ),
              child: Row(
                children: [
                  Text(b.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.label,
                            style: TextStyle(
                              color: selected ? Colors.white : FreezmeColors.neutral,
                              fontWeight: FontWeight.w600, fontSize: 15,
                            )),
                        Text(b.sub,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.75)
                                  : FreezmeColors.muted,
                              fontSize: 12,
                            )),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? Colors.white : Colors.transparent,
                      border: Border.all(
                        color: selected ? FreezmeColors.primary : FreezmeColors.border,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: FreezmeColors.primary, size: 14)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Insight banner ────────────────────────────────────────────────────────────

class _InsightBanner extends StatelessWidget {
  const _InsightBanner({required this.text, this.icon = Icons.auto_awesome});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FreezmeColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FreezmeColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: FreezmeColors.primary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                  color: FreezmeColors.primary, fontSize: 13, fontWeight: FontWeight.w500,
                )),
          ),
        ],
      ),
    );
  }
}
