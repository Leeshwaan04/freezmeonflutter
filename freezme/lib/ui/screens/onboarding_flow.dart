import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../../services/api_client.dart';
import '../../services/photo_upload_service.dart';
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

// Prompts organised by category — shown as labelled tabs
class _PromptCategory {
  const _PromptCategory({required this.label, required this.emoji, required this.prompts});
  final String label;
  final String emoji;
  final List<String> prompts;
}

const _kPromptCategories = [
  _PromptCategory(
    label: 'Real',
    emoji: '💬',
    prompts: [
      'The last time you genuinely helped someone — what did you do?',
      'The thing I\'m most proud of that nobody gave me an award for.',
      'A belief I hold that most people around me don\'t.',
      'What I\'m still figuring out about myself.',
    ],
  ),
  _PromptCategory(
    label: 'Fun',
    emoji: '✨',
    prompts: [
      'The most spontaneous thing I\'ve ever done.',
      'My friends would describe me as...',
      'I\'ll know it\'s going well if...',
      'The random skill I have that nobody expects.',
    ],
  ),
  _PromptCategory(
    label: 'Weird',
    emoji: '🌀',
    prompts: [
      'My most controversial food opinion.',
      'A hill I will absolutely die on.',
      'The thing I do that makes total sense to me and zero sense to others.',
      'Ideal Sunday, but make it oddly specific.',
    ],
  ),
];

class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage> {
  int _step = 1;
  // Steps: 1=Pull, 2=Value, 3=Pace, 4=Freeze, 5=Details, 6=Identity, 7=Photo, 8=Interests, 9=IPV
  static const int _totalSteps = 9;
  bool _showArchetypeResult = false;
  bool _submitting = false;
  bool _hasAttemptedNext = false;

  // ── Moment 1: Pull — forced-choice calibration ──────────────────────────────
  final List<int> _calibrationChoices = []; // 0=A, 1=B per pair index
  DatingIntent? _selectedIntent;
  bool _ageConfirmed = false;

  // ── Moment 2: Value — prompt answer ─────────────────────────────────────────
  int _selectedCategoryIndex = 0;
  String _selectedPrompt = _kPromptCategories[0].prompts[0];
  final TextEditingController _promptAnswerController = TextEditingController();

  // ── Moment 3: Pace — scenario choice ────────────────────────────────────────
  int? _paceChoice; // index into _paceScenarios

  // ── Moment 4: Freeze — presence windows ─────────────────────────────────────
  final Set<String> _presenceBuckets = {'evening'}; // default: evenings

  // ── Moment 5: Face — name, age, gender, photo ───────────────────────────────
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String? _gender; // 'Man', 'Woman', 'Non-binary', 'Prefer not to say'
  File? _photo;

  // ── Moment 6: Interests ──────────────────────────────────────────────────────
  final Set<String> _selectedInterests = {};
  static const int _minInterests = 3;
  static const int _maxInterests = 10;

  // ── Moment 7: IPV — identity verification ───────────────────────────────────
  bool _ipvSkipped = false; // IPV is optional — controls button label

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
      case 5: return _nameController.text.trim().length >= 2 && _validAge != null;
      case 6: return _gender != null;
      case 7: return _photo != null;
      case 8: return _selectedInterests.length >= _minInterests;
      case 9: return true; // IPV is optional — can always proceed
      default: return false;
    }
  }

  int? get _validAge {
    final n = int.tryParse(_ageController.text.trim());
    if (n == null || n < 18 || n > 80) return null;
    return n;
  }

  Future<void> _handleNext(AppFlowController flow) async {
    if (_step == _totalSteps) {
      if (!_showArchetypeResult) {
        if (_submitting) return;
        setState(() => _submitting = true);
        try {
          String? imageUrl;
          if (_photo != null) {
            try {
              imageUrl = await S3PhotoUploadService().uploadPhoto(
                _photo!,
                userId: '',
                photoIndex: 0,
              );
            } catch (e) {
              debugPrint('[Onboarding] photo upload failed: $e');
              // Photo upload failed — show error and block progression
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Photo upload failed. Please check your connection and try again.'),
                    duration: Duration(seconds: 4),
                  ),
                );
              }
              return; // do not proceed without a photo
            }
          }

          final traits = _derivedTraits;
          // Resolve gender prefs: if nothing explicitly selected, use default for gender
          final resolvedGenderPrefs = _selectedGenderPrefs.isNotEmpty
              ? _selectedGenderPrefs
              : _prefToGenderPrefs(
                  (_genderPrefOptions[_gender] ?? ['Everyone']).first);
          await flow.updateOnboardingData(
            name: _nameController.text.trim(),
            bio: _promptAnswerController.text.trim(),
            age: int.tryParse(_ageController.text),
            gender: _gender,
            genderPrefs: resolvedGenderPrefs,
            interests: _selectedInterests.toList(),
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
            imageUrl: imageUrl,
          );
          if (mounted) setState(() => _showArchetypeResult = true);
        } finally {
          if (mounted) setState(() => _submitting = false);
        }
        return;
      }
      flow.isVerified = true;
      flow.replaceStack([AppStage.dailyPool]);
      return;
    }
    setState(() {
      _step++;
      _hasAttemptedNext = false;
    });
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
                        onPressed: _submitting ? null : () {
                          if (_canProceed()) {
                            _handleNext(flow);
                          } else {
                            setState(() => _hasAttemptedNext = true);
                          }
                        },
                        style: FreezmeButtons.primaryFilled,
                        child: _submitting
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white,
                                ),
                              )
                            : Text(
                                _showArchetypeResult
                                    ? 'Let\'s go ❄️'
                                    : _step == _totalSteps
                                        ? (_ipvSkipped
                                            ? 'Skip & reveal my type'
                                            : 'Reveal my type')
                                        : _step == _totalSteps - 1
                                            ? 'Almost there →'
                                            : 'Continue',
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
      case 5: return 'Your Details';
      case 6: return 'Identity';
      case 7: return 'The Face';
      case 8: return 'Your World';
      case 9: return 'Verify';
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
      case 6: return _buildMoment6();
      case 7: return _buildMoment7();
      case 8: return _buildMoment8();
      case 9: return _buildMoment9();
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
            final (label, sub) = switch (intent) {
              DatingIntent.meaningful => ('Something real', 'A genuine, lasting connection'),
              DatingIntent.exploring  => ('Open to see', 'Curious, no pressure'),
              DatingIntent.friendship => ('Connection first', 'Start as friends, see where it goes'),
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
          // Validation hints for step 1
          if (_hasAttemptedNext &&
              (_calibrationChoices.length < kCalibrationPairs.length ||
                  _selectedIntent == null ||
                  !_ageConfirmed))
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_calibrationChoices.length < kCalibrationPairs.length)
                    _ValidationHint(
                      text: 'Choose one from each pair (${_calibrationChoices.length}/${kCalibrationPairs.length} done)',
                    ),
                  if (_selectedIntent == null)
                    const _ValidationHint(text: 'Select what you\'re here for'),
                  if (!_ageConfirmed)
                    const _ValidationHint(text: 'Confirm you are 18 or older to continue'),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Moment 2: The Value ───────────────────────────────────────────────────

  Widget _buildMoment2() {
    final category = _kPromptCategories[_selectedCategoryIndex];
    final answerLen = _promptAnswerController.text.trim().length;
    final hasEnough = answerLen >= 10;

    return SingleChildScrollView(
      key: const ValueKey(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('One thing about you.', style: FreezmeTypography.h1),
          const SizedBox(height: 8),
          const Text(
            'Pick a prompt. Answer honestly — this is the first thing people see.',
            style: FreezmeTypography.body,
          ),
          const SizedBox(height: 24),

          // ── Category tabs (Real / Fun / Weird) ──────────────────────────────
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _kPromptCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _kPromptCategories[i];
                final selected = i == _selectedCategoryIndex;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedCategoryIndex = i;
                    // Auto-select first prompt in category, clear answer
                    _selectedPrompt = _kPromptCategories[i].prompts[0];
                    _promptAnswerController.clear();
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? FreezmeColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? FreezmeColors.primary : FreezmeColors.border,
                      ),
                    ),
                    child: Text(
                      '${cat.emoji}  ${cat.label}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : FreezmeColors.neutral,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // ── Individual prompt chips within selected category ─────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: category.prompts.map((prompt) {
              final selected = prompt == _selectedPrompt;
              // Truncate label to ~32 chars so chips stay readable
              final label = prompt.length > 32 ? '${prompt.substring(0, 30)}…' : prompt;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedPrompt = prompt;
                  _promptAnswerController.clear();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? FreezmeColors.primary.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? FreezmeColors.primary : FreezmeColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? FreezmeColors.primary : FreezmeColors.neutral,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ── Full prompt display ──────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FreezmeColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FreezmeColors.primary.withValues(alpha: 0.25)),
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
          const SizedBox(height: 14),

          // ── Answer field with countdown counter ──────────────────────────────
          TextField(
            controller: _promptAnswerController,
            maxLines: 4,
            maxLength: 280,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) {
              final remaining = (maxLength ?? 280) - currentLength;
              return Text(
                '$remaining left',
                style: TextStyle(
                  fontSize: 12,
                  color: remaining < 30
                      ? Colors.orange
                      : FreezmeColors.muted,
                ),
              );
            },
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
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: hasEnough ? FreezmeColors.primary.withValues(alpha: 0.4) : FreezmeColors.border,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: FreezmeColors.primary, width: 2),
              ),
            ),
          ),

          // ── Profile card preview ─────────────────────────────────────────────
          if (hasEnough) ...[
            const SizedBox(height: 16),
            const Text('How it looks on your profile:', style: FreezmeTypography.bodyMuted),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: FreezmeColors.primary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: FreezmeColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: FreezmeColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.format_quote_rounded,
                            color: FreezmeColors.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedPrompt,
                          style: const TextStyle(
                            fontSize: 11,
                            color: FreezmeColors.muted,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _promptAnswerController.text.trim(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: FreezmeColors.neutral,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_hasAttemptedNext && !hasEnough)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _ValidationHint(
                text: 'Write at least 10 characters to continue',
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Moment 3: The Pace ────────────────────────────────────────────────────

  static const _paceScenarios = [
    (
      title: 'You wait.',
      sub: 'If they\'re interested, they\'ll reach out. No need to chase.',
    ),
    (
      title: 'You send something light.',
      sub: 'Low pressure. Just keeping the door open.',
    ),
    (
      title: 'You check their profile again.',
      sub: 'Decide if you still feel it before doing anything.',
    ),
    (
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

  // ── Moment 5: Your Details ────────────────────────────────────────────────

  Widget _buildMoment5() {
    final nameOk = _nameController.text.trim().length >= 2;
    final ageOk = _validAge != null;
    return SingleChildScrollView(
      key: const ValueKey(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('The Basics.', style: FreezmeTypography.h1),
          const SizedBox(height: 8),
          const Text(
            'Just your first name and age — nothing else is shown without your permission.',
            style: FreezmeTypography.body,
          ),
          const SizedBox(height: 32),

          // Name field — card style
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: nameOk ? FreezmeColors.primary.withValues(alpha: 0.5) : FreezmeColors.border,
                width: nameOk ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8, offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('First name',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: nameOk ? FreezmeColors.primary : FreezmeColors.muted,
                      letterSpacing: 0.8,
                    )),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: FreezmeColors.neutral,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'What do people call you?',
                    hintStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: FreezmeColors.muted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_hasAttemptedNext && !nameOk) ...[
                  const SizedBox(height: 6),
                  const Text('Enter at least 2 characters',
                      style: TextStyle(fontSize: 12, color: Colors.red)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Age field — card style
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: ageOk ? FreezmeColors.primary.withValues(alpha: 0.5) : FreezmeColors.border,
                width: ageOk ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8, offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Age',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ageOk ? FreezmeColors.primary : FreezmeColors.muted,
                      letterSpacing: 0.8,
                    )),
                const SizedBox(height: 6),
                TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: FreezmeColors.neutral,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'How old are you?',
                    hintStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: FreezmeColors.muted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (_hasAttemptedNext && !ageOk) ...[
                  const SizedBox(height: 6),
                  const Text('Must be between 18 and 80',
                      style: TextStyle(fontSize: 12, color: Colors.red)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Warm reassurance note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FreezmeColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Text('🔒', style: TextStyle(fontSize: 18)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your last name is never shared. Age is shown as a range, not exact.',
                    style: TextStyle(fontSize: 12, color: FreezmeColors.neutral, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Moment 6: Identity ────────────────────────────────────────────────────

  // Who does this gender want to meet — drives the matching engine
  static const _genderPrefOptions = {
    'Man':              ['Woman', 'Man', 'Everyone'],
    'Woman':            ['Man', 'Woman', 'Everyone'],
    'Non-binary':       ['Everyone', 'Man', 'Woman', 'Non-binary'],
    'Prefer not to say':['Everyone'],
  };

  List<String> _selectedGenderPrefs = [];

  static const _genderEmoji = {
    'Man': '👨',
    'Woman': '👩',
    'Non-binary': '🌈',
    'Prefer not to say': '✨',
  };

  List<String> _prefToGenderPrefs(String pref) {
    if (pref == 'Everyone') return [];
    return [pref.toLowerCase()];
  }

  Widget _buildMoment6() {
    final prefOptions = _gender != null ? (_genderPrefOptions[_gender] ?? ['Everyone']) : <String>[];
    return SingleChildScrollView(
      key: const ValueKey(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('Tell us about you.', style: FreezmeTypography.h1),
          const SizedBox(height: 8),
          const Text(
            'This shapes who you see and who sees you.',
            style: FreezmeTypography.body,
          ),
          const SizedBox(height: 28),

          // Gender identity
          const Text('I identify as',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: FreezmeColors.muted, letterSpacing: 0.5,
              )),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: ['Man', 'Woman', 'Non-binary', 'Prefer not to say'].map((g) {
              final selected = _gender == g;
              final emoji = _genderEmoji[g] ?? '✨';
              return GestureDetector(
                onTap: () => setState(() {
                  _gender = g;
                  _selectedGenderPrefs = []; // reset pref when gender changes
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? FreezmeColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? FreezmeColors.primary : FreezmeColors.border,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected ? [
                      BoxShadow(
                        color: FreezmeColors.primary.withValues(alpha: 0.2),
                        blurRadius: 8, offset: const Offset(0, 3),
                      ),
                    ] : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        g,
                        style: TextStyle(
                          color: selected ? Colors.white : FreezmeColors.neutral,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle, color: Colors.white, size: 16),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (_hasAttemptedNext && _gender == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: _ValidationHint(text: 'Select how you identify to continue'),
            ),

          // Who they want to meet — only show once gender is selected
          if (_gender != null) ...[
            const SizedBox(height: 28),
            const Text('I want to meet',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: FreezmeColors.muted, letterSpacing: 0.5,
                )),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: prefOptions.map((pref) {
                final selected = _selectedGenderPrefs.isEmpty
                    ? pref == prefOptions.first  // auto-select first
                    : (_selectedGenderPrefs == _prefToGenderPrefs(pref) ||
                       (pref == 'Everyone' && _selectedGenderPrefs.isEmpty));
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedGenderPrefs = _prefToGenderPrefs(pref);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? FreezmeColors.primary.withValues(alpha: 0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? FreezmeColors.primary : FreezmeColors.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      pref,
                      style: TextStyle(
                        color: selected ? FreezmeColors.primary : FreezmeColors.neutral,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FreezmeColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Text('💡', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'We only show you people who match your preference — and who prefer someone like you.',
                      style: TextStyle(fontSize: 12, color: FreezmeColors.neutral, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Moment 7: The Face ────────────────────────────────────────────────────

  Widget _buildMoment7() {
    return SingleChildScrollView(
      key: const ValueKey(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('Your photo.', style: FreezmeTypography.h1),
          const SizedBox(height: 8),
          const Text(
            'One photo of you doing something real — not a posed selfie.',
            style: FreezmeTypography.body,
          ),
          const SizedBox(height: 24),

          // Photo picker — full width card
          GestureDetector(
            onTap: _pickPhoto,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 320,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _photo != null
                      ? FreezmeColors.primary
                      : FreezmeColors.border,
                  width: _photo != null ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _photo != null
                        ? FreezmeColors.primary.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _photo != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.file(_photo!, fit: BoxFit.cover,
                              width: double.infinity, height: double.infinity),
                        ),
                        Positioned(
                          bottom: 16, right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: FreezmeColors.primary.withValues(alpha: 0.08),
                          ),
                          child: const Icon(Icons.add_a_photo_rounded,
                              size: 44, color: FreezmeColors.primary),
                        ),
                        const SizedBox(height: 18),
                        const Text('Tap to add a photo',
                            style: TextStyle(
                              color: FreezmeColors.neutral,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 6),
                        const Text('From your camera roll',
                            style: TextStyle(color: FreezmeColors.muted, fontSize: 13)),
                      ],
                    ),
            ),
          ),

          if (_hasAttemptedNext && _photo == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: _ValidationHint(text: 'Add a photo to continue')),
            ),

          const SizedBox(height: 20),

          // Photo tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FreezmeColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What works best',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: FreezmeColors.neutral,
                    )),
                const SizedBox(height: 10),
                ...[
                  ('✅', 'You doing something you love'),
                  ('✅', 'Clear face, good lighting'),
                  ('❌', 'Group photos or sunglasses'),
                  ('❌', 'Heavy filters or old photos'),
                ].map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text(tip.$1, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 10),
                      Text(tip.$2,
                          style: const TextStyle(
                            fontSize: 13, color: FreezmeColors.neutral)),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Moment 8: Your World — Interests ─────────────────────────────────────

  static const _interestCategories = {
    'Hobbies': ['Music', 'Travel', 'Art', 'Gaming', 'Reading', 'Photography', 'Cooking', 'Writing'],
    'Sports': ['Yoga', 'Gym', 'Running', 'Hiking', 'Cycling', 'Swimming', 'Climbing'],
    'Lifestyle': ['Coffee', 'Foodie', 'Nightlife', 'Movies', 'Wine', 'Concerts', 'Theatre'],
    'Values': ['Mindfulness', 'Sustainability', 'Volunteering', 'Spirituality', 'Family'],
  };

  Widget _buildMoment8() {
    return SingleChildScrollView(
      key: const ValueKey(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('What\'s your world like?', style: FreezmeTypography.h1),
          const SizedBox(height: 8),
          Text(
            'Pick at least $_minInterests, up to $_maxInterests. These shape who sees you.',
            style: FreezmeTypography.body,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${_selectedInterests.length}/$_maxInterests selected',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _selectedInterests.length >= _minInterests
                      ? FreezmeColors.primary
                      : FreezmeColors.muted,
                ),
              ),
              if (_selectedInterests.length < _minInterests)
                Text(
                  '  · pick ${_minInterests - _selectedInterests.length} more',
                  style: const TextStyle(fontSize: 12, color: FreezmeColors.muted),
                ),
            ],
          ),
          const SizedBox(height: 20),
          ..._interestCategories.entries.map((cat) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(cat.key,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FreezmeColors.muted,
                    letterSpacing: 0.5,
                  )),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cat.value.map((item) {
                  final selected = _selectedInterests.contains(item);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedInterests.remove(item);
                        } else if (_selectedInterests.length < _maxInterests) {
                          _selectedInterests.add(item);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected ? FreezmeColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected ? FreezmeColors.primary : FreezmeColors.border,
                        ),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          color: selected ? Colors.white : FreezmeColors.neutral,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          )),
        ],
      ),
    );
  }

  // ── Moment 9: IPV — Identity / Photo Verification ─────────────────────────

  Widget _buildMoment9() {
    final verified = !_ipvSkipped;
    return SingleChildScrollView(
      key: const ValueKey(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('Almost done.', style: FreezmeTypography.h1),
          const SizedBox(height: 8),
          const Text(
            'Freezme is a real-people space. A quick selfie keeps it safe for everyone.',
            style: FreezmeTypography.body,
          ),
          const SizedBox(height: 24),

          // Main verification card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: verified
                    ? FreezmeColors.primary
                    : FreezmeColors.border,
                width: verified ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: FreezmeColors.primary.withValues(alpha: 0.06),
                  blurRadius: 16, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Icon
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        FreezmeColors.primary.withValues(alpha: 0.15),
                        FreezmeColors.primary.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.face_retouching_natural,
                      size: 38, color: FreezmeColors.primary),
                ),
                const SizedBox(height: 16),
                const Text('Selfie Verification',
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: FreezmeColors.neutral,
                    )),
                const SizedBox(height: 8),
                const Text(
                  'A one-time selfie to confirm you\'re a real person.\nNever stored. Never shown to anyone.',
                  style: TextStyle(fontSize: 13, color: FreezmeColors.muted, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _startIPV,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Take selfie now',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: FreezmeColors.primary,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Benefits — styled as a proper card, not a flat list
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: FreezmeColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: FreezmeColors.primary.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What you get',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: FreezmeColors.primary, letterSpacing: 0.3,
                    )),
                const SizedBox(height: 14),
                ...[
                  (Icons.verified_rounded,       'Verified badge on your profile'),
                  (Icons.shield_outlined,         'Higher trust — more matches respond'),
                  (Icons.trending_up_rounded,     '2× more visibility in the daily pool'),
                  (Icons.lock_outline_rounded,    'Only see other verified users'),
                ].map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: FreezmeColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.$1, color: FreezmeColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item.$2,
                            style: const TextStyle(
                              fontSize: 13, color: FreezmeColors.neutral, height: 1.3,
                            )),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Skip — more visible, not hidden
          GestureDetector(
            onTap: () => setState(() => _ipvSkipped = true),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FreezmeColors.border),
              ),
              child: const Text(
                'Skip for now — I\'ll verify later in settings',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13, color: FreezmeColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _startIPV() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null || !mounted) return;

    // Show uploading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading selfie…'), duration: Duration(seconds: 30)),
    );

    try {
      final client = ApiClient.instance;

      // 1. Get presigned selfie upload URL
      final urlResp = await client.dio.post<Map<String, dynamic>>('/verification/selfie-url');
      final uploadUrl = urlResp.data?['uploadUrl'] as String?;
      final selfieKey = urlResp.data?['selfieKey'] as String?;
      if (uploadUrl == null || selfieKey == null) throw Exception('No upload URL returned');

      // 2. Upload selfie directly to S3
      final bytes = await picked.readAsBytes();
      await Dio().put(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': 'image/jpeg',
            'Content-Length': bytes.length,
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      // 3. Notify backend to verify the selfie
      await client.dio.post<void>(
        '/verification/selfie-submit',
        data: {'selfieKey': selfieKey},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() => _ipvSkipped = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selfie submitted — verification usually takes under a minute.'),
            backgroundColor: FreezmeColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        // Selfie verification is non-blocking — allow user to continue
        setState(() => _ipvSkipped = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not upload selfie. You can verify later in your profile.'),
          ),
        );
      }
    }
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

// ── Validation hint ───────────────────────────────────────────────────────────

class _ValidationHint extends StatelessWidget {
  const _ValidationHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 14, color: Color(0xFFE57373)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFE57373),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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
