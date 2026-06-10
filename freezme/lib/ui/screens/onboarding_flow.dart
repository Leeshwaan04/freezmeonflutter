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

// ── Onboarding: 5-step modern flow ───────────────────────────────────────────
// Step 1 — The Pace    (scenario choice)
// Step 2 — Who you are (name, age, gender, interested in)
// Step 3 — Your photo
// Step 4 — Your world  (interests)
// Step 5 — Your intent
// ─────────────────────────────────────────────────────────────────────────────

class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage>
    with SingleTickerProviderStateMixin {
  int _step = 1;
  static const int _totalSteps = 5;
  bool _submitting = false;
  bool _hasAttemptedNext = false;

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
  // DOB-derived age — null until user picks a date (Apple Guideline 1.3).
  DateTime? _dob;
  int? get _age {
    if (_dob == null) return null;
    final today = DateTime.now();
    int age = today.year - _dob!.year;
    if (today.month < _dob!.month ||
        (today.month == _dob!.month && today.day < _dob!.day)) age--;
    return age;
  }

  bool get _dobOk => _age != null && _age! >= 18;

  Future<void> _pickDob(BuildContext context) async {
    final now = DateTime.now();
    final latest18 = DateTime(now.year - 18, now.month, now.day);
    final initial = _dob ?? latest18;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(latest18) ? latest18 : initial,
      firstDate: DateTime(now.year - 100),
      lastDate: latest18,
      helpText: 'Your date of birth',
      fieldLabelText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }
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
    super.dispose();
  }

  bool _canProceed() {
    switch (_step) {
      case 1: return _paceChoice != null;
      case 2: return _nameController.text.trim().length >= 2 && _dobOk && _gender != null;
      case 3: return _photo != null;
      case 4: return _selectedInterests.length >= _minInterests;
      case 5: return _selectedIntent != null;
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
          age:               _age ?? 18,
          gender:            _normalizeGender(_gender),
          genderPrefs:       resolvedGenderPrefs,
          intent:            _selectedIntent,
          interests:         _selectedInterests.toList(),
          personalityTraits: const [],
          energyType:        null,
          lifestyleFactors:  const [],
          imageUrl:          imageUrl,
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
      case 1: return 'The Pace';
      case 2: return 'Who you are';
      case 3: return 'Your photo';
      case 4: return 'Your world';
      case 5: return 'Your intent';
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
      case 1: return _buildPace();
      case 2: return _buildWhoYouAre();
      case 3: return _buildPhoto();
      case 4: return _buildInterests();
      case 5: return _buildIntent();
      default: return const SizedBox();
    }
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
          const Text('Date of birth', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: FreezmeColors.muted)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _pickDob(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hasAttemptedNext && !_dobOk
                      ? FreezmeColors.error
                      : _dob != null
                          ? FreezmeColors.primary.withValues(alpha: 0.5)
                          : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_outlined,
                      color: _dob != null ? FreezmeColors.primary : FreezmeColors.muted,
                      size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _dob != null
                          ? '${_dob!.day.toString().padLeft(2, '0')} / '
                            '${_dob!.month.toString().padLeft(2, '0')} / '
                            '${_dob!.year}  •  Age ${_age!}'
                          : 'Select your date of birth',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _dob != null ? FreezmeColors.neutral : FreezmeColors.muted.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: FreezmeColors.muted.withValues(alpha: 0.5), size: 20),
                ],
              ),
            ),
          ),
          if (_hasAttemptedNext && _dob == null)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text('Please enter your date of birth',
                  style: TextStyle(fontSize: 12, color: FreezmeColors.error)),
            ),
          if (_hasAttemptedNext && _dob != null && !_dobOk)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text('You must be 18 or older to use Freezme',
                  style: TextStyle(fontSize: 12, color: FreezmeColors.error)),
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
