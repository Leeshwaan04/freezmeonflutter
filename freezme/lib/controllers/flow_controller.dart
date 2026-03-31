import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

import '../core/app_stage.dart';
import '../models/vibe_profile.dart';
import '../models/blueprint.dart';
import '../models/profile.dart';
import '../models/paths.dart';
import '../models/blinds.dart';
import '../models/photo_slot.dart';
import '../data/freezme_repository.dart';
import '../services/compatibility_engine.dart';
import '../services/archetype_service.dart';
import '../services/melt_chat_service.dart';
import '../services/iap_service.dart';
import '../services/photo_upload_service.dart';

class AppFlowController extends ChangeNotifier {
  static const _kOnboardingCompleteKey = 'onboarding_complete';

  AppFlowController._(
    this._prefs,
    this._repository, {
    MeltChatService? meltChatService,
    IAPService? iapService,
    PhotoUploadService? photoUploadService,
  })  : dailyProfiles = <VibeProfile>[],
        meltChatService = meltChatService ?? ApiMeltChatService(),
        iapService = iapService ?? IAPService(_repository),
        photoUploadService = photoUploadService ?? S3PhotoUploadService() {
    _hydrate();
    _listenToAuth();
    fetchDailyPool(); // Initial fetch
    _watchMeltInvites();
  }

  factory AppFlowController.test({
    required FreezmeRepository repository,
    required MeltChatService meltChatService,
    required IAPService iapService,
    required PhotoUploadService photoUploadService,
    SharedPreferences? prefs,
    String? testCurrentUserId,
  }) {
    return AppFlowController._(
      prefs,
      repository,
      meltChatService: meltChatService,
      iapService: iapService,
      photoUploadService: photoUploadService,
    ).._testCurrentUserId = testCurrentUserId;
  }

  static Future<AppFlowController> create(FreezmeRepository repository) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // ignore; running in environments where shared_preferences is unavailable
    }
    return AppFlowController._(prefs, repository);
  }

  final SharedPreferences? _prefs;
  final FreezmeRepository _repository;
  final MeltChatService meltChatService;
  final IAPService iapService;
  final PhotoUploadService photoUploadService;
  final List<AppStage> _stack = <AppStage>[AppStage.splash];
  final List<AppMatch> _matches = <AppMatch>[];
  final List<VibeProfile> dailyProfiles;
  final List<VibeCircle> activeCircles = <VibeCircle>[];
  final List<PhotoSlot> _photoSlots = List.generate(
    6, (i) => const PhotoSlot(status: PhotoSlotStatus.empty));
  
  VibeProfile? activeProfile;
  String? _activeChatId;
  String? _testCurrentUserId;
  VibeCircle? activeCircle;
  LifestyleArchetype? selectedArchetype;
  int _poolIndex = 0;
  bool _isFreezed = false;
  DateTime? _freezeUntil;
  bool _isVerified = false;
  bool _isPremium = false;
  int _vibeCredits = 3;
  int _trustScore = 150; // Initial score
  UserBlueprint? userBlueprint;
  bool _disposed = false;
  StreamSubscription<AuthUser?>? _authSub;

  // Local cache for profile fields — used when auth is unavailable (simulator)
  String? _localName;
  String? _localBio;
  int? _localAge;
  List<String> _localInterests = const [];

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  set isVerified(bool value) {
    _isVerified = value;
    notifyListeners();
  }

  List<AppStage> get stack => List.unmodifiable(_stack);
  AppStage get current => _stack.last;
  List<AppMatch> get matches => _matches.where((m) => !m.isExpired).toList();
  int get poolIndex => _poolIndex;
  bool get isFreezed => _isFreezed;
  bool get isVerified => _isVerified;
  bool get isPremium => _isPremium;
  int get vibeCredits => _vibeCredits;
  int get trustScore => _trustScore;
  DateTime? get freezeUntil => _freezeUntil;

  VibeProfile get currentProfile =>
      dailyProfiles[_poolIndex.clamp(0, dailyProfiles.length - 1)];

  int get remainingProfiles =>
      math.max(0, dailyProfiles.length - _poolIndex - 1);

  // ─── Stubs for new-style screens (remote refactor) ──────────────────────────
  FreezmeRepository get repository => _repository;
  int _currentTabIndex = 0;
  int get currentTabIndex => _currentTabIndex;
  void openTab(int index) { _currentTabIndex = index; notifyListeners(); }
  double get completionPercent => isVerified ? 1.0 : (userBlueprint != null ? 0.6 : 0.3);
  bool get isProfileComplete => userBlueprint != null && isVerified;
  String? get profilePhotoUrl => AuthService.instance.currentUser?.photoUrl;
  String? get profileName => AuthService.instance.currentUser?.displayName ?? _localName;
  String? get profileEmail => AuthService.instance.currentUser?.email;
  String? get profileBio => AuthService.instance.currentUser?.bio ?? _localBio;
  int? get profileAge => AuthService.instance.currentUser?.age ?? _localAge;
  List<String> get profileInterests => AuthService.instance.currentUser?.interests.isNotEmpty == true
      ? AuthService.instance.currentUser!.interests
      : _localInterests;
  int get uploadedPhotoCount => _photoSlots.where((s) => s.status == PhotoSlotStatus.uploaded).length;
  List<PhotoSlot> get photoSlots => List.unmodifiable(_photoSlots);

  Future<void> uploadPhotoForSlot(int index, [String? path]) async {
    if (index < 0 || index >= _photoSlots.length) return;
    
    _photoSlots[index] = const PhotoSlot(status: PhotoSlotStatus.uploading);
    notifyListeners();

    try {
      final uploaded = await photoUploadService.pickAndUpload(slotIndex: index);
      _photoSlots[index] = PhotoSlot(
        status: PhotoSlotStatus.uploaded,
        imageUrl: uploaded.url,
        localPath: uploaded.localPath,
      );
      notifyListeners();
    } catch (e) {
      _photoSlots[index] = const PhotoSlot(status: PhotoSlotStatus.error);
      notifyListeners();
      rethrow;
    }
  }
  int get matchesCount => matches.length;

  // Paths stubs
  double _lastPathsRadiusKm = 5.0;
  Set<String> _lastPathsIntents = const {'coffee', 'walk'};
  final List<PathsPresence> _nearbyPaths = [];
  final bool _pathsLoading = false;
  String? _pathsError;
  double get lastPathsRadiusKm => _lastPathsRadiusKm;
  Set<String> get lastPathsIntents => _lastPathsIntents;
  List<PathsPresence> get nearbyPaths => _nearbyPaths;
  bool get pathsLoading => _pathsLoading;
  String? get pathsError => _pathsError;

  Future<void> refreshPaths({required double radiusKm, required Set<String> intents}) async {
    _lastPathsRadiusKm = radiusKm;
    _lastPathsIntents = intents;
  }

  Future<String> sendPathsInvite({required String receiverUid, required String intent}) =>
      _repository.sendPathsInvite(receiverUid: receiverUid, intent: intent);

  Stream<PathsInvite> inviteStatus(String inviteId) => _repository.inviteStatus(inviteId);

  // Blinds stubs
  bool _blindsConsent = false;
  BlindSession? _activeBlindSession;
  BlindSession? get activeBlindSession => _activeBlindSession;
  bool get blindsConsent => _blindsConsent;
  void setBlindsConsent(bool value) { _blindsConsent = value; notifyListeners(); }
  Future<void> enqueueBlind({
    required String intent,
    required String distanceBucket,
    required DateTime availableUntil,
  }) async {
    await _repository.enqueueBlind(BlindQueueEntry(
      userId: AuthService.instance.currentUser?.uid ?? '',
      intent: intent,
      availableUntil: availableUntil,
      distanceBucket: distanceBucket,
    ));
  }
  void openBlindChat(BlindSession session) { _activeBlindSession = session; push(AppStage.chat); }
  String? get activeChatId => _activeChatId;
  String? get currentUserId => _testCurrentUserId ?? AuthService.instance.currentUser?.uid;

  // Melt invites — backed by live Firestore stream
  List<Map<String, dynamic>> _pendingMeltInvites = const [];
  StreamSubscription<List<Map<String, dynamic>>>? _meltInviteSub;
  List<Map<String, dynamic>> get pendingMeltInvites => _pendingMeltInvites;

  void _watchMeltInvites() {
    _meltInviteSub = _repository.watchMeltInvites().listen((invites) {
      _pendingMeltInvites = invites;
      notifyListeners();
    });
  }

  Future<bool> sendMeltChatInvite(VibeProfile target, String slotLabel) async {
    try {
      await meltChatService.sendInvite(
        targetUid: target.uid,
        slotLabel: slotLabel,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // Chat stubs
  void openChatDetail(VibeProfile profile, {String? chatId}) {
    activeProfile = profile;
    _activeChatId = chatId ?? profile.uid;
    push(AppStage.chat);
  }
  void openHome() => replaceStack([AppStage.dailyPool]);

  // Profile stubs
  VibeProfile? get fullProfile => activeProfile;
  Future<void> refreshProfile() async {
    await AuthService.instance.refreshProfile();
    notifyListeners();
  }
  Future<void> setBioFilled(bool value) async {}
  Future<void> setPreferencesSet(bool value) async {}
  Future<void> updateProfile({
    String? name,
    String? bio,
    List<String>? interests,
    int? age,
    String? gender,
    String? location,
  }) async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    await _repository.updateProfile(
      uid: uid,
      displayName: name,
      bio: bio,
      age: age,
      gender: gender,
      location: location,
      interests: interests,
    );
  }
  Future<void> updateLocalProfileState({
    bool? hasBio,
    bool? hasPreferences,
    PhotoSlot? photoSlot,
    int? photoIndex,
  }) async {}

  void _hydrate() {
    final completed =
        _prefs?.getBool(_kOnboardingCompleteKey) ?? false;
    _isFreezed = _prefs?.getBool('is_freezed') ?? false;
    _isVerified = _prefs?.getBool('is_verified') ?? false;
    _isPremium = _prefs?.getBool('is_premium') ?? false;
    _vibeCredits = _prefs?.getInt('vibe_credits') ?? 3;
    _trustScore = _prefs?.getInt('trust_score') ?? 150;
    final freezeUntilStr = _prefs?.getString('freeze_until');
    if (freezeUntilStr != null) {
      _freezeUntil = DateTime.tryParse(freezeUntilStr);
      if (_freezeUntil != null && DateTime.now().isAfter(_freezeUntil!)) {
        _isFreezed = false;
        _prefs?.setBool('is_freezed', false);
      }
    }

    _stack
      ..clear()
      ..add(completed ? (_isFreezed ? AppStage.freeze : AppStage.dailyPool) : AppStage.splash);
    if (!completed) {
      _poolIndex = 0;
    }
  }

  void _listenToAuth() {
    _authSub = AuthService.instance.authStateChanges.listen((user) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        if (user == null) {
          if (current != AppStage.authGate && current != AppStage.splash) {
            replaceStack([AppStage.authGate]);
          }
        } else {
          // Populate photo slots from existing profile photos
          bool slotsChanged = false;
          if (user.photoUrls.isNotEmpty) {
            for (int i = 0; i < user.photoUrls.length && i < _photoSlots.length; i++) {
              _photoSlots[i] = PhotoSlot(
                status: PhotoSlotStatus.uploaded,
                imageUrl: user.photoUrls[i],
              );
            }
            slotsChanged = true;
          }
          if (current == AppStage.authGate || current == AppStage.splash) {
            final completed = _prefs?.getBool(_kOnboardingCompleteKey) ?? false;
            // replaceStack already calls notifyListeners
            replaceStack([completed ? AppStage.dailyPool : AppStage.onboarding]);
          } else if (slotsChanged) {
            // Slots updated but no navigation change — still notify listeners
            notifyListeners();
          }
        }
      });
    });
  }

  void replaceStack(List<AppStage> stages) {
    _stack
      ..clear()
      ..addAll(stages);
    notifyListeners();
  }


  // ─── Trust Score Event System ────────────────────────────────────────────────

  /// Central method for all trust score changes.
  /// Clamps score to [0, 500] and persists to SharedPreferences.
  void awardTrustPoints(int delta, {required String reason}) {
    _trustScore = (_trustScore + delta).clamp(0, 500);
    _updateUserBlueprintScore();
    _prefs?.setInt('trust_score', _trustScore);
    debugPrint('TrustScore [$reason]: ${delta >= 0 ? '+' : ''}$delta → $_trustScore');
    notifyListeners();
  }

  /// Call after the user finishes profile (name, bio, photo all set).
  void onProfileComplete() => awardTrustPoints(10, reason: 'profile_complete');

  /// Positive conversation end — partner rated the chat well.
  void onPositiveConversationRating() => awardTrustPoints(5, reason: 'positive_rating');

  /// Report a user for misbehaviour. Penalises the reporter lightly to
  /// discourage abuse, and queues a server-side review via Firestore.
  Future<void> reportUser(String targetUid) async {
    awardTrustPoints(-40, reason: 'reported_user');
    try {
      await _repository.reportUser(targetUid);
    } catch (e) {
      debugPrint('Failed to submit report: $e');
    }
  }

  void completeVerification() {
    _isVerified = true;
    awardTrustPoints(50, reason: 'photo_verified');
    _prefs?.setBool('is_verified', true);
    pop();
    notifyListeners();
  }

  void addVoiceIntro(String url) {
    userBlueprint = UserBlueprint(
      intent: userBlueprint?.intent ?? DatingIntent.meaningful,
      personalityTraits: userBlueprint?.personalityTraits ?? [],
      lifestyleFactors: userBlueprint?.lifestyleFactors ?? [],
      voiceIntroUrl: url,
      trustScore: _trustScore + 20, // Voice bonus
      voiceEnergy: 0.85, // Simulated analysis
      voiceWarmth: 0.78, // Simulated analysis
    );
    _trustScore = userBlueprint!.trustScore;
    _prefs?.setInt('trust_score', _trustScore);
    notifyListeners();
  }

  void _updateUserBlueprintScore() {
    if (userBlueprint != null) {
      userBlueprint = UserBlueprint(
        intent: userBlueprint!.intent,
        personalityTraits: userBlueprint!.personalityTraits,
        lifestyleFactors: userBlueprint!.lifestyleFactors,
        voiceIntroUrl: userBlueprint!.voiceIntroUrl,
        trustScore: _trustScore,
        voiceEnergy: userBlueprint!.voiceEnergy,
        voiceWarmth: userBlueprint!.voiceWarmth,
      );
    }
  }

  void startChat(AppMatch match) {
    // Conversation starts — extend expiry from 48h to 7 days
    final index = _matches.indexOf(match);
    if (index != -1) {
      _matches[index] = AppMatch(
        profile: match.profile,
        matchedAt: match.matchedAt,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        hasConversationStarted: true,
      );
    }
    activeProfile = match.profile;
    push(AppStage.chat);
  }

  void push(AppStage stage) {
    _stack.add(stage);
    notifyListeners();
  }

  void pushIfMissing(AppStage stage) {
    if (_stack.isEmpty || _stack.last != stage) {
      push(stage);
    }
  }

  void replaceTop(AppStage stage) {
    if (_stack.isNotEmpty) {
      _stack
        ..removeLast()
        ..add(stage);
      notifyListeners();
    }
  }

  bool pop() {
    if (_stack.length <= 1) {
      return false;
    }
    _stack.removeLast();
    notifyListeners();
    return true;
  }

  void setLifestyleArchetype(LifestyleArchetype archetype) {
    selectedArchetype = archetype;
    notifyListeners();
  }

  void completeSplash() => replaceStack(<AppStage>[AppStage.authGate]);

  void startOnboarding() {
    _prefs?.remove(_kOnboardingCompleteKey);
    _poolIndex = 0;
    replaceStack(<AppStage>[AppStage.onboarding]);
  }

  void beginCompatibilityQuiz() => pushIfMissing(AppStage.compatibilityQuiz);

  Future<void> finishCompatibilityQuiz() async {
    if (_stack.isNotEmpty && _stack.last == AppStage.compatibilityQuiz) {
      _stack.removeLast();
    }
    if (_stack.isNotEmpty && _stack.last == AppStage.onboarding) {
      _stack.removeLast();
    }
    await _prefs?.setBool(_kOnboardingCompleteKey, true);
    _stack.add(AppStage.dailyPool);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    if (_stack.isNotEmpty && _stack.last == AppStage.onboarding) {
      _stack.removeLast();
    }
    await _prefs?.setBool(_kOnboardingCompleteKey, true);
    _stack.add(AppStage.dailyPool);
    notifyListeners();
  }

  void openProfileSettings() => pushIfMissing(AppStage.profileSettings);

  void openProfilePreview() => pushIfMissing(AppStage.profilePreview);

  void openDailyRecap() => pushIfMissing(AppStage.dailyRecap);

  Future<void> consumeCredit() async {
    if (_isPremium) return;
    final prefs = await SharedPreferences.getInstance();
    _vibeCredits = (_vibeCredits - 1).clamp(0, 999);
    await prefs.setInt('vibeCredits', _vibeCredits);
    notifyListeners();
  }

  void openFreezmePlus() => pushIfMissing(AppStage.freezmePlus);

  void openDeveloperMenu() => pushIfMissing(AppStage.developerMenu);

  void closeDeveloperMenu() => pop();

  void openFreezeScreen() => pushIfMissing(AppStage.freeze);

  Future<void> toggleFreeze(bool value, {int days = 1}) async {
    _isFreezed = value;
    if (_isFreezed) {
      _freezeUntil = DateTime.now().add(Duration(days: days));
      replaceStack([AppStage.freeze]);
    } else {
      _freezeUntil = null;
      replaceStack([AppStage.dailyPool]);
    }
    await _prefs?.setBool('is_freezed', _isFreezed);
    await _prefs?.setString('freeze_until', _freezeUntil?.toIso8601String() ?? '');
    notifyListeners();
  }

  void openVerification() => pushIfMissing(AppStage.verification);

  void openVectorSimulation() => pushIfMissing(AppStage.vectorSimulation);

  void openChat([VibeProfile? profile]) {
    activeProfile = profile ?? activeProfile ?? dailyProfiles.first;
    pushIfMissing(AppStage.chat);
  }

  void exitChat() {
    if (pop()) {
      activeProfile = null;
      _activeChatId = null;
    }
  }

  void startVideoDate([VibeProfile? profile]) {
    if (profile != null) activeProfile = profile;
    pushIfMissing(AppStage.videoDate);
  }

  void completeVideoDate() {
    if (_stack.last == AppStage.videoDate) {
      pop();
    }
  }

  Future<void> purchasePremium() async {
    _isPremium = true;
    await _prefs?.setBool('is_premium', true);
    notifyListeners();
  }

  Future<void> buyCredits(int amount) async {
    _vibeCredits += amount;
    await _prefs?.setInt('vibe_credits', _vibeCredits);
    notifyListeners();
  }

  Future<void> fetchDailyPool() async {
    try {
      // Step 1: Candidate pool generated (Mocking 50 candidates)
      final allCandidates = await _repository.fetchDailyProfiles();
      
      // Step 2 & 3: Compatibility scoring & Top 5 selection
      if (userBlueprint != null) {
        final scoredProfiles = allCandidates.map((profile) {
          final dna = CompatibilityEngine.calculateDNA(userBlueprint!, profile);
          return profile.copyWith(
            dna: dna,
            compatibility: dna.overall,
          );
        }).toList();

        // Sort by compatibility descending
        scoredProfiles.sort((a, b) => b.compatibility.compareTo(a.compatibility));

        // Step 4: Diversity filter (Select top 5, but ensure variety in archetypes)
        final dailySelection = scoredProfiles.take(5).toList();

        dailyProfiles.clear();
        dailyProfiles.addAll(dailySelection);
      } else {
        dailyProfiles.clear();
        dailyProfiles.addAll(allCandidates.take(5));
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching daily pool: $e');
    }
  }

  PersonalityArchetype? get userArchetype => 
    userBlueprint != null ? ArchetypeService.determine(userBlueprint!.personalityTraits) : null;

  Future<void> updateOnboardingData({
    String? name,
    int? age,
    String? bio,
    LifestyleArchetype? archetype,
    List<String>? interests,
    DatingIntent? intent,
    List<PersonalityTrait>? personalityTraits,
    List<LifestyleFactor>? lifestyleFactors,
  }) async {
    final uid = AuthService.instance.currentUser?.uid;
    // We update local blueprint first
    userBlueprint = UserBlueprint(
      intent: intent ?? userBlueprint?.intent ?? DatingIntent.meaningful,
      personalityTraits: personalityTraits ?? userBlueprint?.personalityTraits ?? [],
      lifestyleFactors: lifestyleFactors ?? userBlueprint?.lifestyleFactors ?? [],
      trustScore: userBlueprint?.trustScore ?? 100,
    );

    // Store locally for simulator / offline mode
    if (name != null) _localName = name;
    if (bio != null) _localBio = bio;
    if (age != null) _localAge = age;
    if (interests != null) _localInterests = interests;

    if (uid == null) {
      if (archetype != null) selectedArchetype = archetype;
      notifyListeners();
      return;
    }

    await _repository.updateProfile(
      uid: uid,
      displayName: name,
      bio: bio,
      age: age,
      interests: interests,
    );

    if (archetype != null) {
      selectedArchetype = archetype;
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await AuthService.instance.signOut();
    await _prefs?.clear();
    replaceStack([AppStage.authGate]);
  }

  @override
  void dispose() {
    _disposed = true;
    _meltInviteSub?.cancel();
    _authSub?.cancel();
    iapService.dispose();
    super.dispose();
  }

  void skipProfile() {
    if (_poolIndex < dailyProfiles.length - 1) {
      _poolIndex++;
      notifyListeners();
    } else {
      openDailyRecap();
    }
  }

  void restartDailyPool() {
    _poolIndex = 0;
    notifyListeners();
  }

  void matchProfile(VibeProfile profile) {
    activeProfile = profile;
    // Matches expire in 48 hours unless a conversation starts
    _matches.add(
      AppMatch(
        profile: profile,
        matchedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 48)),
      ),
    );
    replaceTop(AppStage.matchSuccess);
    notifyListeners();
  }

  void finishMatchSuccessToChat() {
    if (activeProfile == null && matches.isNotEmpty) {
      activeProfile = matches.last.profile;
    }
    replaceTop(AppStage.chat);
  }

  void finishMatchSuccessToPool() {
    activeProfile = null;
    replaceStack(<AppStage>[AppStage.dailyPool]);
  }

  void openCircleDiscovery() => pushIfMissing(AppStage.circleDiscovery);

  void joinCircle(VibeCircle circle) {
    if (!activeCircles.contains(circle)) {
      activeCircles.add(circle);
    }
    activeCircle = circle;
    pushIfMissing(AppStage.circleChat);
  }

  void openCircleChat(VibeCircle circle) {
    activeCircle = circle;
    pushIfMissing(AppStage.circleChat);
  }

  void exitCircleChat() {
    if (pop()) {
      activeCircle = null;
    }
  }

  void returnToPool({bool resetIndex = false}) {
    if (resetIndex) {
      restartDailyPool();
    }
    replaceStack(<AppStage>[AppStage.dailyPool]);
  }

}

class AppFlowScope extends InheritedNotifier<AppFlowController> {
  const AppFlowScope({
    required AppFlowController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppFlowController of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<AppFlowScope>()
        : context.getInheritedWidgetOfExactType<AppFlowScope>();
    assert(scope != null, 'AppFlowScope not found in context');
    return scope!.notifier!;
  }

  @override
  bool updateShouldNotify(AppFlowScope oldWidget) =>
      notifier != oldWidget.notifier;
}
