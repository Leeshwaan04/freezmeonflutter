import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../../services/photo_upload_service.dart';
import '../../core/app_stage.dart';
import '../../services/auth_service.dart';
import '../../models/blueprint.dart';

// ── Onboarding: 7-step modern flow ───────────────────────────────────────────
// Step 1 — The Pull    (A/B energy calibration)
// Step 2 — The Value   (prompt answer)
// Step 3 — The Pace    (scenario choice)
// Step 4 — Who you are (name, age, gender, interested in)
// Step 5 — Your photo
// Step 6 — Your world  (interests)
// Step 7 — Your intent
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

class _OnboardingFlowPageState extends State<OnboardingFlowPage>
    with SingleTickerProviderStateMixin {
  int _step = 1;
  static const int _totalSteps = 7;
  bool _submitting = false;
  bool _hasAttemptedNext = false;

  // ── Step 1: The Pull ──────────────────────────────────────────────────────
  final List<int> _calibrationChoices = [];

  List<PersonalityTrait> get _derivedTraits {
    if (_calibrationChoices.length < 4) return [];
    return [
      _calibrationChoices[2] == 0 ? PersonalityTrait.introvert : PersonalityTrait.extrovert,
      _calibrationChoices[1] == 0 ? PersonalityTrait.planner : PersonalityTrait.spontaneous,
      _calibrationChoices[3] == 0 ? PersonalityTrait.logical : PersonalityTrait.emotional,
      _calibrationChoices[0] == 0 ? PersonalityTrait.cautious : PersonalityTrait.adventurous,
    ];
  }

  /// Derive the energy type from "The Pull" calibration so it actually feeds
  /// matching (the algorithm weights energy compatibility 20pts; it was null
  /// for every user because onboarding never set it).
  ///   introvert × planner    → deepDiver  (reflective, depth)
  ///   introvert × spontaneous → quietStorm (calm exterior, inner world)
  ///   extrovert × planner    → roomIgniter (social, high energy)
  ///   extrovert × spontaneous → openRoad   (spontaneous, always moving)
  EnergyType? get _derivedEnergyType {
    if (_calibrationChoices.length < 4) return null;
    final extrovert = _calibrationChoices[2] == 1;
    final spontaneous = _calibrationChoices[1] == 1;
    if (!extrovert && !spontaneous) return EnergyType.deepDiver;
    if (!extrovert && spontaneous) return EnergyType.quietStorm;
    if (extrovert && !spontaneous) return EnergyType.roomIgniter;
    return EnergyType.openRoad;
  }

  // ── Step 2: The Value ─────────────────────────────────────────────────────
  String _selectedPrompt = _kPrompts[0];
  final TextEditingController _promptAnswerController = TextEditingController();

  // ── Step 3: The Pace ──────────────────────────────────────────────────────
  int? _paceChoice;

  static const _paceScenarios = [
    (title: 'You wait.', sub: 'If they\'re interested, they\'ll reach out. No need to chase.'),
    (title: 'You send something light.', sub: 'Low pressure. Just keeping the door open.'),
    (title: 'You check their profile again.', sub: 'Decide if you still feel it before doing anything.'),
    (title: 'You move on.', sub: 'If they wanted to, they would have. Your energy is valuable.'),
  ];

  // ── Step 4: Who you are ───────────────────────────────────────────────────
  final TextEditingController _nameController = TextEditingController();
  int _age = 22;
  String? _gender;
  static const _genderPrefOptions = {
    'Man':               ['Women', 'Men', 'Everyone'],
    'Woman':             ['Men', 'Women', 'Everyone'],
    'Non-binary':        ['Everyone', 'Men', 'Women', 'Non-binary'],
    'Prefer not to say': ['Everyone'],
  };
  List<String> _selectedGenderPrefs = [];

  List<String> _prefToGenderPrefs(String pref) {
    switch (pref) {
      case 'Men':        return ['man'];
      case 'Women':      return ['woman'];
      case 'Non-binary': return ['nonbinary'];
      default:           return ['man', 'woman', 'nonbinary'];
    }
  }

  // Normalize display gender label → server value (lowercase)
  String _normalizeGender(String? g) {
    switch (g) {
      case 'Man':               return 'man';
      case 'Woman':             return 'woman';
      case 'Non-binary':        return 'nonbinary';
      default:                  return 'other';
    }
  }

  // ── Step 5: Photo ─────────────────────────────────────────────────────────
  File? _photo;

  // ── Step 6: Interests ─────────────────────────────────────────────────────
  final Set<String> _selectedInterests = {};
  static const int _minInterests = 3;
  static const int _maxInterests = 10;
  static const _interestCategories = {
    'Hobbies':   ['Music', 'Travel', 'Art', 'Gaming', 'Reading', 'Photography', 'Cooking', 'Writing'],
    'Sports':    ['Yoga', 'Gym', 'Running', 'Hiking', 'Cycling', 'Swimming', 'Climbing'],
    'Lifestyle': ['Coffee', 'Foodie', 'Nightlife', 'Movies', 'Wine', 'Concerts', 'Theatre'],
    'Values':    ['Mindfulness', 'Sustainability', 'Volunteering', 'Spirituality', 'Family'],
  };

  // ── Step 7: Intent ────────────────────────────────────────────────────────
  DatingIntent? _selectedIntent;

  @override
  void dispose() {
    _nameController.dispose();
    _promptAnswerController.dispose();
    super.dispose();
  }

  bool _canProceed() {
    switch (_step) {
      case 1: return _calibrationChoices.length == kCalibrationPairs.length;
      case 2: return _promptAnswerController.text.trim().length >= 40;
      case 3: return _paceChoice != null;
      case 4: return _nameController.text.trim().length >= 2 && _gender != null;
      case 5: return _photo != null;
      case 6: return _selectedInterests.length >= _minInterests;
      case 7: return _selectedIntent != null;
      default: return false;
    }
  }

  void _goNext(AppFlowController flow) {
    if (!_canProceed()) { setState(() => _hasAttemptedNext = true); return; }
    if (_step < _totalSteps) { setState(() { _step++; _hasAttemptedNext = false; }); return; }
    _submit(flow);
  }

  void _goBack() {
    if (_step > 1) setState(() { _step--; _hasAttemptedNext = false; });
  }

  Future<void> _submit(AppFlowController flow) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      String? imageUrl;
      if (_photo != null) {
        try {
          final svc = kDebugMode ? MockPhotoUploadService() : S3PhotoUploadService();
          imageUrl = await svc.uploadPhoto(_photo!, userId: '', photoIndex: 0);
        } catch (e) {
          debugPrint('[Onboarding] photo upload failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Photo upload failed. Please try again.'),
              duration: Duration(seconds: 4),
            ));
          }
          return;
        }
      }
      // Normalize genderPrefs to lowercase server values
      final rawPrefs = _selectedGenderPrefs.isNotEmpty
          ? _selectedGenderPrefs
          : _prefToGenderPrefs((_genderPrefOptions[_gender] ?? ['Everyone']).first);
      final resolvedGenderPrefs = rawPrefs
          .map((g) => g == 'Man' ? 'man' : g == 'Woman' ? 'woman' : g == 'Non-binary' ? 'nonbinary' : g.toLowerCase())
          .toList();
      try {
        await flow.updateOnboardingData(
          name:              _nameController.text.trim(),
          age:               _age,
          gender:            _normalizeGender(_gender),
          genderPrefs:       resolvedGenderPrefs,
          intent:            _selectedIntent,
          interests:         _selectedInterests.toList(),
          personalityTraits: _derivedTraits,
          energyType:        _derivedEnergyType,
          lifestyleFactors:  const [],
          imageUrl:          imageUrl,
          bio:               _promptAnswerController.text.trim(),
          promptAnswer:      PromptAnswer(
            prompt: _selectedPrompt,
            answer: _promptAnswerController.text.trim(),
          ),
          paceSignal:        _paceChoice == 0 ? PaceSignal.takesTheirTime
                             : _paceChoice == 3 ? PaceSignal.quickConnector
                             : PaceSignal.movesWithInterest,
        );
      } catch (e) {
        String errorDetail = e.toString();
        // Extract server error message from DioException if available
        try {
          final dio = e as dynamic;
          if (dio?.response?.data != null) {
            errorDetail = dio.response.data.toString();
          }
        } catch (_) {}
        debugPrint('[Onboarding] profile save failed: $e');
        debugPrint('[Onboarding] error detail: $errorDetail');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('We couldn\'t save your profile right now. Please check your connection and try again.'),
            duration: Duration(seconds: 4),
          ));
        }
        return;
      }
      if (mounted) {
        flow.isVerified = true;
        flow.replaceStack([AppStage.dailyPool]);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _stepLabel(int step) {
    switch (step) {
      case 1: return 'The Pull';
      case 2: return 'The Value';
      case 3: return 'The Pace';
      case 4: return 'Who you are';
      case 5: return 'Your photo';
      case 6: return 'Your world';
      case 7: return 'Your intent';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    return Scaffold(
      // Same calm surface token as the in-app tabs (was a hardcoded off-token
      // near-white) so the backdrop is consistent from onboarding into the app.
      backgroundColor: FreezmeColors.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  if (_step > 1)
                    GestureDetector(
                      onTap: _goBack,
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8, offset: const Offset(0, 2),
                          )],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 16, color: FreezmeColors.neutral),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () async {
                         await AuthService.instance.signOut();
                         if (mounted) flow.replaceStack([AppStage.authGate]);
                      },
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8, offset: const Offset(0, 2),
                          )],
                        ),
                        child: const Icon(Icons.logout_rounded,
                            size: 16, color: FreezmeColors.error),
                      ),
                    ),
                  const Spacer(),
                  Row(
                    children: List.generate(_totalSteps, (i) {
                      final active = i + 1 == _step;
                      final done   = i + 1 < _step;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: active ? 18 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: done || active ? FreezmeColors.primary : const Color(0xFFDDD8F0),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  Text(_stepLabel(_step),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: FreezmeColors.muted)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
                      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: KeyedSubtree(key: ValueKey(_step), child: _buildStep(flow)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: SizedBox(
                width: double.infinity, height: 56,
                child: FilledButton(
                  onPressed: _submitting ? null : () => _goNext(flow),
                  style: FilledButton.styleFrom(
                    backgroundColor: FreezmeColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_step == _totalSteps ? 'Let\'s go' : 'Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(AppFlowController flow) {
    switch (_step) {
      case 1: return _buildPull();
      case 2: return _buildValue();
      case 3: return _buildPace();
      case 4: return _buildWhoYouAre();
      case 5: return _buildPhoto();
      case 6: return _buildInterests();
      case 7: return _buildIntent();
      default: return const SizedBox();
    }
  }

  Widget _buildPull() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Which pulls\nyou more?',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
                  color: FreezmeColors.neutral, height: 1.15)),
          const SizedBox(height: 6),
          const Text('No right answer. Pick what you actually feel.',
              style: TextStyle(fontSize: 15, color: FreezmeColors.muted)),
          const SizedBox(height: 28),
          ...kCalibrationPairs.asMap().entries.map((entry) {
            final i    = entry.key;
            final pair = entry.value;
            final chosen = _calibrationChoices.length > i ? _calibrationChoices[i] : -1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _CalibrationPairCard(
                optionA: pair.optionA, optionB: pair.optionB, chosen: chosen,
                onChoose: (choice) => setState(() {
                  if (_calibrationChoices.length <= i) _calibrationChoices.add(choice);
                  else _calibrationChoices[i] = choice;
                }),
              ),
            );
          }),
          if (_hasAttemptedNext && _calibrationChoices.length < kCalibrationPairs.length)
            _ValidationHint(
              text: 'Choose one from each pair (${_calibrationChoices.length}/${kCalibrationPairs.length} done)',
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildValue() {
    final charCount = _promptAnswerController.text.trim().length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('One thing\nabout you.',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
                  color: FreezmeColors.neutral, height: 1.15)),
          const SizedBox(height: 6),
          const Text('Pick a prompt. This is the first thing people see.',
              style: TextStyle(fontSize: 15, color: FreezmeColors.muted)),
          const SizedBox(height: 20),

          // Vertical prompt list — every prompt visible at once (no hidden
          // "Prompt N" chips). The selected prompt expands inline to reveal the
          // answer field. Switching prompts does NOT clear what's been typed.
          ...List.generate(_kPrompts.length, (i) {
            final prompt = _kPrompts[i];
            final sel = prompt == _selectedPrompt;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: sel
                      ? FreezmeColors.primary.withValues(alpha: 0.07)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: sel
                        ? FreezmeColors.primary.withValues(alpha: 0.45)
                        : FreezmeColors.border,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tappable prompt row
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: sel
                          ? null
                          : () => setState(() => _selectedPrompt = prompt),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Radio indicator
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: sel
                                      ? FreezmeColors.primary
                                      : FreezmeColors.muted.withValues(alpha: 0.4),
                                  width: 2,
                                ),
                                color: sel ? FreezmeColors.primary : Colors.transparent,
                              ),
                              child: sel
                                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                prompt,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  height: 1.4,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                                  color: sel
                                      ? FreezmeColors.neutral
                                      : FreezmeColors.neutral.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Inline answer field — only under the selected prompt
                    if (sel)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _promptAnswerController,
                              maxLines: 5,
                              maxLength: 280,
                              autofocus: false,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Your answer...',
                                hintStyle: TextStyle(
                                    color: FreezmeColors.muted.withValues(alpha: 0.6)),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.all(16),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: FreezmeColors.border)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: charCount >= 40
                                        ? FreezmeColors.primary.withValues(alpha: 0.4)
                                        : FreezmeColors.border,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: FreezmeColors.primary, width: 2)),
                                counterStyle: const TextStyle(
                                    fontSize: 11, color: FreezmeColors.muted),
                              ),
                            ),
                            if (charCount >= 40)
                              const Padding(
                                padding: EdgeInsets.only(top: 10),
                                child: _InsightBanner(
                                    text: 'This shows on your profile exactly as written.',
                                    icon: Icons.visibility_outlined))
                            else if (_hasAttemptedNext)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _ValidationHint(
                                    text: '$charCount/40 characters minimum')),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPace() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('You matched with\nsomeone interesting.',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
                  color: FreezmeColors.neutral, height: 1.15)),
          const SizedBox(height: 6),
          const Text('It\'s been 2 days. They haven\'t messaged. You:',
              style: TextStyle(fontSize: 15, color: FreezmeColors.muted)),
          const SizedBox(height: 28),
          ..._paceScenarios.asMap().entries.map((entry) {
            final i   = entry.key;
            final s   = entry.value;
            final sel = _paceChoice == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => setState(() => _paceChoice = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: sel ? FreezmeColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: sel
                        ? [BoxShadow(color: FreezmeColors.primary.withValues(alpha: 0.25),
                            blurRadius: 14, offset: const Offset(0, 5))]
                        : [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : FreezmeColors.neutral)),
                      const SizedBox(height: 3),
                      Text(s.sub, style: TextStyle(fontSize: 13,
                          color: sel ? Colors.white.withValues(alpha: 0.75) : FreezmeColors.muted)),
                    ])),
                    if (sel)
                      Container(width: 24, height: 24,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 14)),
                  ]),
                ),
              ),
            );
          }),
          if (_paceChoice != null)
            const Padding(padding: EdgeInsets.only(top: 4),
              child: _InsightBanner(text: 'We\'ll match you with people who move at a compatible pace.',
                  icon: Icons.people_outline_rounded)),
          if (_hasAttemptedNext && _paceChoice == null)
            const _ValidationHint(text: 'Pick one to continue'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildWhoYouAre() {
    final nameOk = _nameController.text.trim().length >= 2;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hey, who\nare you?',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
                  color: FreezmeColors.neutral, height: 1.15)),
          const SizedBox(height: 6),
          const Text('The basics — 30 seconds.',
              style: TextStyle(fontSize: 15, color: FreezmeColors.muted)),
          const SizedBox(height: 28),
          TextField(
            controller: _nameController, onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: FreezmeColors.neutral),
            decoration: InputDecoration(
              hintText: 'Your first name',
              hintStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                  color: FreezmeColors.muted.withValues(alpha: 0.4)),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: nameOk ? FreezmeColors.primary.withValues(alpha: 0.5) : Colors.transparent,
                    width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: FreezmeColors.primary, width: 2)),
              suffixIcon: nameOk ? const Icon(Icons.check_circle_rounded, color: FreezmeColors.primary, size: 22) : null,
              errorText: _hasAttemptedNext && !nameOk ? 'At least 2 characters' : null,
            ),
          ),
          const SizedBox(height: 24),
          Row(children: [
            const Text('Age', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FreezmeColors.muted)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: FreezmeColors.primary, borderRadius: BorderRadius.circular(99)),
              child: Text('$_age', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ]),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: FreezmeColors.primary,
              inactiveTrackColor: const Color(0xFFE4DFF5),
              thumbColor: Colors.white,
              overlayColor: FreezmeColors.primary.withValues(alpha: 0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
            ),
            child: Slider(value: _age.toDouble(), min: 18, max: 60, divisions: 42,
                onChanged: (v) => setState(() => _age = v.round())),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('18', style: TextStyle(fontSize: 11, color: FreezmeColors.muted.withValues(alpha: 0.6))),
              Text('60+', style: TextStyle(fontSize: 11, color: FreezmeColors.muted.withValues(alpha: 0.6))),
            ]),
          ),
          const SizedBox(height: 24),
          const Text('I identify as', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FreezmeColors.muted)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8,
            children: ['Man', 'Woman', 'Non-binary', 'Prefer not to say'].map((g) {
              final sel = _gender == g;
              return GestureDetector(
                onTap: () => setState(() { _gender = g; _selectedGenderPrefs = []; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? FreezmeColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: sel
                        ? [BoxShadow(color: FreezmeColors.primary.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))]
                        : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
                  ),
                  child: Text(g, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : FreezmeColors.neutral)),
                ),
              );
            }).toList(),
          ),
          if (_hasAttemptedNext && _gender == null)
            const Padding(padding: EdgeInsets.only(top: 8),
                child: _ValidationHint(text: 'Select how you identify')),
          if (_gender != null) ...[
            const SizedBox(height: 24),
            const Text('Interested in', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FreezmeColors.muted)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8,
              children: (_genderPrefOptions[_gender] ?? ['Everyone']).map((pref) {
                final resolved = _prefToGenderPrefs(pref);
                final isSel = _selectedGenderPrefs.isEmpty
                    ? pref == (_genderPrefOptions[_gender] ?? ['Everyone']).first
                    : _selectedGenderPrefs.toString() == resolved.toString();
                return GestureDetector(
                  onTap: () => setState(() => _selectedGenderPrefs = resolved),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSel ? FreezmeColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: isSel
                          ? [BoxShadow(color: FreezmeColors.primary.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))]
                          : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
                    ),
                    child: Text(pref, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                        color: isSel ? Colors.white : FreezmeColors.neutral)),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Add your\nbest photo.',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
                color: FreezmeColors.neutral, height: 1.15)),
        const SizedBox(height: 6),
        const Text('Real. No filters. Just you.',
            style: TextStyle(fontSize: 15, color: FreezmeColors.muted)),
        const SizedBox(height: 6),
        Text('Helps real people recognize you — you can add more later.',
            style: TextStyle(fontSize: 12.5, color: FreezmeColors.muted.withValues(alpha: 0.7))),
        const SizedBox(height: 18),
        Expanded(
          child: GestureDetector(
            onTap: _pickPhoto,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: _photo == null
                    ? Border.all(color: _hasAttemptedNext
                        ? FreezmeColors.error.withValues(alpha: 0.5)
                        : const Color(0xFFE8E2F8), width: 1.5)
                    : null,
                boxShadow: [BoxShadow(
                  color: _photo != null ? FreezmeColors.primary.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24, offset: const Offset(0, 8),
                )],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: _photo != null
                    ? Stack(fit: StackFit.expand, children: [
                        Image.file(_photo!, fit: BoxFit.cover),
                        Positioned(bottom: 16, right: 16,
                          child: GestureDetector(
                            onTap: _pickPhoto,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(99)),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.photo_library_rounded, color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text('Change', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ]),
                            ),
                          )),
                      ])
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(width: 80, height: 80,
                          decoration: BoxDecoration(color: FreezmeColors.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
                          child: const Icon(Icons.add_photo_alternate_rounded, size: 36, color: FreezmeColors.primary)),
                        const SizedBox(height: 16),
                        const Text('Tap to upload', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: FreezmeColors.neutral)),
                        const SizedBox(height: 4),
                        Text('From your camera roll', style: TextStyle(fontSize: 13, color: FreezmeColors.muted.withValues(alpha: 0.8))),
                      ]),
              ),
            ),
          ),
        ),
        if (_hasAttemptedNext && _photo == null)
          const Padding(padding: EdgeInsets.only(top: 10),
              child: Center(child: _ValidationHint(text: 'Add a photo to continue'))),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _buildInterests() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('What\'s your\nworld like?',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
                color: FreezmeColors.neutral, height: 1.15)),
        const SizedBox(height: 6),
        Row(children: [
          Text('Pick at least $_minInterests', style: const TextStyle(fontSize: 15, color: FreezmeColors.muted)),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _selectedInterests.length >= _minInterests ? FreezmeColors.primary : const Color(0xFFEDE9FF),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text('${_selectedInterests.length}/$_maxInterests',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: _selectedInterests.length >= _minInterests ? Colors.white : FreezmeColors.primary)),
          ),
        ]),
        const SizedBox(height: 24),
        ..._interestCategories.entries.map((cat) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cat.key.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: FreezmeColors.muted, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8,
              children: cat.value.map((item) {
                final sel = _selectedInterests.contains(item);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (sel) _selectedInterests.remove(item);
                    else if (_selectedInterests.length < _maxInterests) _selectedInterests.add(item);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? FreezmeColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: sel
                          ? [BoxShadow(color: FreezmeColors.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))]
                          : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
                    ),
                    child: Text(item, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : FreezmeColors.neutral)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 22),
          ],
        )),
        if (_hasAttemptedNext && _selectedInterests.length < _minInterests)
          _ValidationHint(text: 'Pick at least $_minInterests to continue'),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildIntent() {
    final intents = [
      (DatingIntent.meaningful, 'Something real', 'Looking for a genuine, lasting connection', const Color(0xFFFF6B6B)),
      (DatingIntent.exploring,  'Open to see',    'Curious and open — no pressure',            const Color(0xFFFFB347)),
      (DatingIntent.friendship, 'Connection first','Start as friends, see where it goes',       const Color(0xFF4ECDC4)),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('What brings\nyou here?',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
                color: FreezmeColors.neutral, height: 1.15)),
        const SizedBox(height: 6),
        const Text('We match by intent. Be honest.',
            style: TextStyle(fontSize: 15, color: FreezmeColors.muted)),
        const SizedBox(height: 28),
        ...intents.map((entry) {
          final (intent, label, sub, accent) = entry;
          final sel = _selectedIntent == intent;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedIntent = intent),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: sel ? FreezmeColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: sel
                      ? [BoxShadow(color: FreezmeColors.primary.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))]
                      : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: sel ? Colors.white.withValues(alpha: 0.2) : accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      intent == DatingIntent.meaningful ? Icons.favorite_rounded
                          : intent == DatingIntent.exploring ? Icons.explore_rounded
                          : Icons.handshake_rounded,
                      color: sel ? Colors.white : accent, size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : FreezmeColors.neutral)),
                    const SizedBox(height: 2),
                    Text(sub, style: TextStyle(fontSize: 13,
                        color: sel ? Colors.white.withValues(alpha: 0.75) : FreezmeColors.muted)),
                  ])),
                  if (sel)
                    Container(width: 24, height: 24,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 14)),
                ]),
              ),
            ),
          );
        }),
        if (_hasAttemptedNext && _selectedIntent == null)
          const _ValidationHint(text: 'Pick one to continue'),
        const SizedBox(height: 16),
      ]),
    );
  }

  static const _kMaxPhotoBytes = 8 * 1024 * 1024; // 8 MB

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    final bytes = await file.length();
    if (bytes > _kMaxPhotoBytes && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Photo is too large (max 8 MB). Please choose a smaller image.'),
        duration: Duration(seconds: 3),
      ));
      return;
    }

    if (mounted) setState(() => _photo = file);
  }
}

// ── Calibration pair card ─────────────────────────────────────────────────────

class _CalibrationPairCard extends StatelessWidget {
  const _CalibrationPairCard({
    required this.optionA, required this.optionB,
    required this.chosen, required this.onChoose,
  });
  final String optionA, optionB;
  final int chosen;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _OptionTile(label: optionA, selected: chosen == 0, onTap: () => onChoose(0))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('or', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: FreezmeColors.muted.withValues(alpha: 0.6))),
      ),
      Expanded(child: _OptionTile(label: optionB, selected: chosen == 1, onTap: () => onChoose(1))),
    ]);
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.label, required this.selected, required this.onTap});
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [BoxShadow(color: FreezmeColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Text(label, style: TextStyle(fontSize: 12, height: 1.45,
            color: selected ? Colors.white : FreezmeColors.neutral,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
            maxLines: 5, overflow: TextOverflow.ellipsis),
      ),
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
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, size: 14, color: FreezmeColors.error),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(
            fontSize: 12, color: FreezmeColors.error, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

// ── Insight banner ────────────────────────────────────────────────────────────

class _InsightBanner extends StatelessWidget {
  const _InsightBanner({required this.text, this.icon = Icons.auto_awesome_rounded});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FreezmeColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FreezmeColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Icon(icon, color: FreezmeColors.primary, size: 17),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(
            fontSize: 13, color: FreezmeColors.primary, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
