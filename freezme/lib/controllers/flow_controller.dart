import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_stage.dart';
import '../models/profile.dart';

class AppFlowController extends ChangeNotifier {
  static const _kOnboardingCompleteKey = 'onboarding_complete';

  AppFlowController._(this._prefs) : dailyProfiles = _mockProfiles() {
    _hydrate();
  }

  static Future<AppFlowController> create() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // ignore; running in environments where shared_preferences is unavailable
    }
    return AppFlowController._(prefs);
  }

  final SharedPreferences? _prefs;
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

  static List<VibeProfile> _mockProfiles() => const <VibeProfile>[
        VibeProfile(
          id: 1,
          name: 'Emma',
          age: 24,
          imageUrl:
              'https://images.unsplash.com/photo-1546961329-78bef0414d7c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx5b3VuZyUyMHdvbWFuJTIwcG9ydHJhaXR8ZW58MXx8fHwxNzYwOTQ2MDQ5fDA&ixlib=rb-4.1.0&q=80&w=1080',
          compatibility: 92,
          bio:
              'Adventure seeker | Coffee addict | Let\'s explore the city together ☕',
          distance: '2 km away',
          archetypes: [LifestyleArchetype.brunch, LifestyleArchetype.travel],
        ),
        VibeProfile(
          id: 2,
          name: 'Alex',
          age: 27,
          imageUrl:
              'https://images.unsplash.com/flagged/photo-1596479042555-9265a7fa7983?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx5b3VuZyUyMG1hbiUyMHBvcnRyYWl0fGVufDF8fHx8MTc2MDkzNjI2MHww&ixlib=rb-4.1.0&q=80&w=1080',
          compatibility: 88,
          bio:
              'Fitness enthusiast | Foodie | Looking for meaningful connections 💪',
          distance: '5 km away',
          archetypes: [LifestyleArchetype.gym],
        ),
        VibeProfile(
          id: 3,
          name: 'Sophie',
          age: 26,
          imageUrl:
              'https://images.unsplash.com/photo-1591969851586-adbbd4accf81?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxyb21hbnRpYyUyMGNvdXBsZXxlbnwxfHx8fDE3NjA5Nzg1Nzh8MA&ixlib=rb-4.1.0&q=80&w=1080',
          compatibility: 85,
          bio:
              'Artist at heart | Music lover | Deep conversations over small talk 🎨',
          distance: '3 km away',
          archetypes: [LifestyleArchetype.clubbing, LifestyleArchetype.brunch],
        ),
      ];
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
