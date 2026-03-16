import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_stage.dart';
import '../models/vibe_profile.dart';
import '../models/blueprint.dart';
import '../models/profile.dart';
import '../data/freezme_repository.dart';

class AppFlowController extends ChangeNotifier {
  static const _kOnboardingCompleteKey = 'onboarding_complete';

  AppFlowController._(this._prefs, this._repository) : dailyProfiles = <VibeProfile>[] {
    _hydrate();
    fetchDailyPool(); // Initial fetch
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
  final List<AppStage> _stack = <AppStage>[AppStage.splash];
  final List<AppMatch> matches = <AppMatch>[];
  final List<VibeProfile> dailyProfiles;
  final List<VibeCircle> activeCircles = <VibeCircle>[];
  VibeProfile? activeProfile;
  VibeCircle? activeCircle;
  LifestyleArchetype? selectedArchetype;
  String? _pendingInviteSlot;
  int _poolIndex = 0;
  bool _isFreezed = false;
  DateTime? _freezeUntil;
  bool _isVerified = false;
  bool _isPremium = false;
  int _vibeCredits = 3;
  UserBlueprint? userBlueprint;

  set isVerified(bool value) {
    _isVerified = value;
    notifyListeners();
  }

  List<AppStage> get stack => List.unmodifiable(_stack);
  AppStage get current => _stack.last;
  int get poolIndex => _poolIndex;
  bool get isFreezed => _isFreezed;
  bool get isVerified => _isVerified;
  bool get isPremium => _isPremium;
  int get vibeCredits => _vibeCredits;
  DateTime? get freezeUntil => _freezeUntil;

  VibeProfile get currentProfile =>
      dailyProfiles[_poolIndex.clamp(0, dailyProfiles.length - 1)];

  int get remainingProfiles =>
      math.max(0, dailyProfiles.length - _poolIndex - 1);

  void _hydrate() {
    final completed =
        _prefs?.getBool(_kOnboardingCompleteKey) ?? false;
    _isFreezed = _prefs?.getBool('is_freezed') ?? false;
    _isVerified = _prefs?.getBool('is_verified') ?? false;
    _isPremium = _prefs?.getBool('is_premium') ?? false;
    _vibeCredits = _prefs?.getInt('vibe_credits') ?? 3;
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

  void replaceStack(List<AppStage> stages) {
    _stack
      ..clear()
      ..addAll(stages);
    notifyListeners();
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

  Future<void> completeVerification() async {
    isVerified = true;
    await _prefs?.setBool('is_verified', true);
    pop();
    notifyListeners();
  }

  void openChat([VibeProfile? profile]) {
    activeProfile = profile ?? activeProfile ?? dailyProfiles.first;
    pushIfMissing(AppStage.chat);
  }

  void exitChat() {
    if (pop()) {
      activeProfile = null;
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
      final profiles = await _repository.fetchDailyProfiles();
      dailyProfiles.clear();
      dailyProfiles.addAll(profiles);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching daily pool: $e');
    }
  }

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // We update local blueprint first
    userBlueprint = UserBlueprint(
      intent: intent ?? userBlueprint?.intent ?? DatingIntent.meaningful,
      personalityTraits: personalityTraits ?? userBlueprint?.personalityTraits ?? [],
      lifestyleFactors: lifestyleFactors ?? userBlueprint?.lifestyleFactors ?? [],
      trustScore: userBlueprint?.trustScore ?? 100,
    );

    if (uid == null) {
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
    await FirebaseAuth.instance.signOut();
    await _prefs?.clear();
    replaceStack([AppStage.authGate]);
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
    matches.add(
      AppMatch(
        profile: profile,
        matchedAt: DateTime.now(),
      ),
    );
    replaceTop(AppStage.matchSuccess);
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
