import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_localizations/flutter_localizations.dart';


import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/firestore_freezme_repository.dart';
import 'data/freezme_repository.dart';
import 'data/mock_freezme_repository.dart';
import 'models/paths.dart';
import 'models/blinds.dart'; // Added
import 'models/vibe_profile.dart'; // Added
import 'services/location_service.dart';
import 'services/melt_chat_service.dart';
import 'services/photo_upload_service.dart';
import 'services/push_notification_service.dart';
import 'services/iap_service.dart';
import 'router.dart';

import 'ui/theme.dart';
import 'ui/shared/bottom_nav_bar.dart';
import 'ui/splash/splash_screen.dart';
import 'ui/auth/auth_gate.dart';
import 'ui/onboarding/enhanced_onboarding.dart';
import 'ui/chat/chat_list_page.dart';
import 'ui/chat/chat_screen_page.dart';

import 'ui/home/home_page.dart';
import 'ui/paths/paths_page.dart';
import 'ui/blinds/blinds_page.dart';
import 'ui/components/freezme_logo.dart';
import 'ui/profile/profile_completion_page.dart';
import 'ui/profile/profile_settings_page.dart';
import 'ui/profile/profile_preview_page.dart';
import 'ui/profile/edit_profile_page.dart';
import 'ui/recap/daily_recap_page.dart';
import 'ui/settings/freezme_plus_page.dart';
import 'ui/match_success/match_success_page.dart'; // Added
import 'services/offline_queue_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await PushNotificationService().initialize();
  runApp(const FreezmeApp());
}

enum AppStage {
  splash,
  authGate,
  onboarding,
  profileCompletion, // NEW: Profile completion after onboarding
  dailyPool,
  chatList,

  paths,
  blinds,
  matchSuccess,
  chat,
  profileSettings,
  profilePreview,
  editProfile, // NEW: Edit profile with forms
  dailyRecap,
  freezmePlus,
  developerMenu,
}



class AppMatch {
  const AppMatch({
    required this.profile,
    required this.matchedAt,
    this.scheduledSlot,
  });

  final VibeProfile profile;
  final DateTime matchedAt;
  final String? scheduledSlot;
}

class AppFlowController extends ChangeNotifier {
  static const _kOnboardingCompleteKey = 'onboarding_complete';
  static const _kGuidelinesAcceptedKey = 'guidelines_accepted';

  AppFlowController._(
    this._prefs, {
    PhotoUploadService? photoUploadService,
    MeltChatService? meltChatService,
    FreezmeRepository? repository,
    LocationService? locationService,

    bool skipHydrate = false,
    IAPService? iapService,
  }) : _photoUploadService = photoUploadService ?? FirebasePhotoUploadService(),
       _meltChatService = meltChatService ?? FirebaseMeltChatService(),
       _repository = repository ?? FirestoreFreezmeRepository(fallback: MockFreezmeRepository()),
       _locationService = locationService ?? LocationService(),
       photoSlots = List<PhotoSlot>.generate(6, (_) => const PhotoSlot()),

       dailyProfiles = _mockProfiles() {
    if (iapService != null) {
      this.iapService = iapService;
    } else {
      this.iapService = IAPService(_repository, onSuccess: () {
        isPremium = true;
        notifyListeners();
      });
    }
    _offlineQueue = OfflineQueueService(_prefs);
    if (!skipHydrate) {
      _hydrate();
    }
  }

  static Future<AppFlowController> create({
    PhotoUploadService? photoUploadService,
    MeltChatService? meltChatService,
    FreezmeRepository? repository,
    LocationService? locationService,
  }) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // ignore; running in environments where shared_preferences is unavailable
    }
    return AppFlowController._(
      prefs,
      photoUploadService: photoUploadService,
      meltChatService: meltChatService,
      repository: repository,
      locationService: locationService,
    );
  }

  static AppFlowController test({
    SharedPreferences? prefs,
    PhotoUploadService? photoUploadService,
    MeltChatService? meltChatService,
    FreezmeRepository? repository,
    LocationService? locationService,

    bool skipHydrate = true,
    IAPService? iapService,
  }) {
    return AppFlowController._(
      prefs,
      photoUploadService: photoUploadService,
      meltChatService: meltChatService,
      repository: repository,
      locationService: locationService,
      skipHydrate: skipHydrate,
      iapService: iapService,
    );
  }

  final SharedPreferences? _prefs;
  final PhotoUploadService _photoUploadService;
  final MeltChatService _meltChatService;
  final FreezmeRepository _repository;
  final LocationService _locationService;
  late final IAPService iapService;
  late final OfflineQueueService _offlineQueue;
  final List<AppStage> _stack = <AppStage>[AppStage.splash];
  List<AppStage> get stack => List.unmodifiable(_stack);

  final List<AppMatch> matches = <AppMatch>[];
  final List<VibeProfile> dailyProfiles;
  final List<PhotoSlot> photoSlots;
  String? profileName;
  String? profileEmail;
  String? profilePhotoUrl;
  bool notificationsEnabled = true;
  bool onlineStatusEnabled = true;
  bool readReceiptsEnabled = false;
  bool guidelinesAccepted = false;
  bool hasBio = false;
  bool hasPreferences = false;
  VibeProfile? activeProfile;
  String? activeChatId;
  String? _pendingInviteSlot;
  int _poolIndex = 0;
  int superVibesRemaining = 1;
  bool isSendingAction = false;
  bool pathsLoading = false;
  String? pathsError;
  List<PathsPresence> nearbyPaths = const [];
  Set<String> lastPathsIntents = const {'Friends', 'Dates'};
  double lastPathsRadiusKm = 10;
  bool isPremium = false;
  VibeProfile? fullProfile;
  StreamSubscription? _blindSessionSub;
  StreamSubscription? _activeBlindSub;
  StreamSubscription? _meltInviteSub;
  BlindSession? activeBlindSession;
  List<Map<String, dynamic>> pendingMeltInvites = [];
  bool _isSearchingBlind = false;

  AppStage get current => _stack.last;
  int get poolIndex => _poolIndex;
  int get vibesRemaining => math.max(0, dailyProfiles.length - _poolIndex - 1);
  List<PhotoSlot> get currentPhotoSlots => List.unmodifiable(photoSlots);

  VibeProfile get currentProfile =>
      dailyProfiles[_poolIndex.clamp(0, dailyProfiles.length - 1)];

  int get remainingProfiles =>
      math.max(0, dailyProfiles.length - _poolIndex - 1);
  int get matchesCount => matches.length;
  int get uploadedPhotoCount =>
      photoSlots.where((p) => p.status == PhotoSlotStatus.uploaded).length;
  bool get isProfileComplete =>
      uploadedPhotoCount >= 2 && hasBio && hasPreferences && guidelinesAccepted;
  int get completionPercent {
    // Simple heuristic: photos (40%), bio (30%), preferences (20%), onboarding (10%).
    final photosScore = (uploadedPhotoCount / photoSlots.length * 40).clamp(0, 40);
    final bioScore = hasBio ? 30 : 0;
    final prefsScore = hasPreferences ? 20 : 0;
    final onboardingScore = stack.contains(AppStage.onboarding) ? 0 : 10;
    return (photosScore + bioScore + prefsScore + onboardingScore)
        .clamp(0, 100)
        .round();
  }
  FreezmeRepository get repository => _repository;
  MeltChatService get meltChatService => _meltChatService;

  void _hydrate() {
    final completed = _prefs?.getBool(_kOnboardingCompleteKey) ?? false;
    guidelinesAccepted = _prefs?.getBool(_kGuidelinesAcceptedKey) ?? false;
    _stack
      ..clear()
      ..add(completed ? AppStage.dailyPool : AppStage.splash);
    if (!completed) {
      _poolIndex = 0;
    }
    unawaited(_loadProfilePhotos());
    unawaited(_loadProfileBasics());
    _loadSettings();

    _blindSessionSub = _repository.watchUserBlindSessions().listen((sessions) {
      // Always keep active session state in sync
      if (sessions.isNotEmpty) {
        // If we are already in a chat, don't clobber it unless it's the same one updating
        // or we are just discovering it. 
        if (activeBlindSession == null || activeBlindSession!.id == sessions.first.id) {
           activeBlindSession = sessions.first;
           notifyListeners();
        }
      } else {
        if (activeBlindSession != null) {
          activeBlindSession = null;
          notifyListeners();
        }
      }

      // Auto-navigation logic
      if (sessions.isNotEmpty && _isSearchingBlind) {
        _isSearchingBlind = false;
        // Navigate to the active blind session
        final session = sessions.first;
        openBlindChat(session);
      }
    });

    _meltInviteSub = _repository.watchMeltInvites().listen((invites) {
      pendingMeltInvites = invites;
      notifyListeners();
    });
  }

  void replaceStack(List<AppStage> stages) {
    _stack
      ..clear()
      ..addAll(stages);
    notifyListeners();
  }

  void push(AppStage stage) {
    // Prevent duplicate stages to avoid GlobalKey conflicts
    if (_stack.isEmpty || _stack.last != stage) {
      _stack.add(stage);
      notifyListeners();
    }
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

  void completeSplash() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final completed = _prefs?.getBool(_kOnboardingCompleteKey) ?? false;
      if (completed) {
        replaceStack(<AppStage>[AppStage.dailyPool]);
      } else {
        replaceStack(<AppStage>[AppStage.onboarding]);
      }
    } else {
      replaceStack(<AppStage>[AppStage.authGate]);
    }
  }

  void startOnboarding() {
    _prefs?.remove(_kOnboardingCompleteKey);
    _poolIndex = 0;
    replaceStack(<AppStage>[AppStage.onboarding]);
  }

  // Save onboarding progress
  Future<void> saveOnboardingProgress({
    String? name,
    int? age,
    String? location,
    String? bio,
    List<String>? interests,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (age != null) data['age'] = age;
    if (location != null) data['location'] = location;
    if (bio != null) data['bio'] = bio;
    if (interests != null) data['interests'] = interests;
    if (interests != null) data['interests'] = interests;
    
    if (data.isNotEmpty) {
      await _prefs?.setString('onboarding_progress', jsonEncode(data));
    }
  }

  void updateLocalProfileState({
    bool? hasBio,
    bool? hasPreferences,
    PhotoSlot? photoSlot,
    int? photoIndex,
  }) {
    if (photoSlot != null && photoIndex != null && photoIndex >= 0 && photoIndex < photoSlots.length) {
      photoSlots[photoIndex] = photoSlot;
    }
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    String? bio,
    List<String>? interests,
    int? age,
    String? gender,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (name != null) profileName = name;
    if (bio != null) hasBio = bio.isNotEmpty;
    
    // Update local state immediately for UX
    notifyListeners();

    // Persist to backend
    await _repository.updateProfile(
      uid: uid,
      displayName: name,
      bio: bio,
      interests: interests,
      age: age,
      gender: gender,
    );
  }

  Map<String, dynamic>? getOnboardingProgress() {
    final json = _prefs?.getString('onboarding_progress');
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> completeOnboarding() async {
    if (_stack.isNotEmpty && _stack.last == AppStage.onboarding) {
      _stack.removeLast();
    }
    await _prefs?.setBool(_kOnboardingCompleteKey, true);
    await _prefs?.setBool(_kGuidelinesAcceptedKey, true);
    guidelinesAccepted = true;
    await _prefs?.remove('onboarding_progress'); // Clear saved progress
    _stack.add(AppStage.dailyPool);
    notifyListeners();
  }

  Future<void> acceptGuidelines() async {
    guidelinesAccepted = true;
    await _prefs?.setBool(_kGuidelinesAcceptedKey, true);
    notifyListeners();
  }

  bool get blindsConsent => _prefs?.getBool('blinds_consent') ?? false;

  Future<void> setBlindsConsent(bool value) async {
    await _prefs?.setBool('blinds_consent', value);
    notifyListeners();
  }



  void openProfilePreview() => pushIfMissing(AppStage.profilePreview);

  void openDailyRecap() => pushIfMissing(AppStage.dailyRecap);

  void openFreezmePlus() => pushIfMissing(AppStage.freezmePlus);

  void openDeveloperMenu() => pushIfMissing(AppStage.developerMenu);

  void closeDeveloperMenu() => pop();

  void openChat([VibeProfile? profile]) {
    activeProfile = profile ?? activeProfile ?? dailyProfiles.first;
    activeBlindSession = null;
    _activeBlindSub?.cancel();
    pushIfMissing(AppStage.chat);
  }

  void exitChat() {
    if (pop()) {
      activeProfile = null;
    }
  }

  void skipProfile() {
    if (dailyProfiles.isEmpty) return;
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

  Future<void> refreshPaths({
    required double radiusKm,
    required Set<String> intents,
  }) async {
    pathsLoading = true;
    pathsError = null;
    notifyListeners();
    lastPathsRadiusKm = radiusKm;
    lastPathsIntents = intents;
    try {
      final location = await _locationService.getCoarseLocation();
      
      // Update our own presence while we fetch others
      unawaited(_repository.upsertPathsPresence(PathsPresence(
        uid: FirebaseAuth.instance.currentUser?.uid ?? '',
        intents: intents.toList(),
        radiusKm: radiusKm,
        visibleUntil: DateTime.now().add(const Duration(hours: 2)),
        lat: location.lat,
        lng: location.lng,
        displayName: fullProfile?.name,
        imageUrl: photoSlots.firstWhere((s) => s.imageUrl != null, orElse: () => const PhotoSlot()).imageUrl,
      )));

      final results = await _repository
          .fetchNearbyPaths(
            radiusKm: radiusKm,
            intents: intents,
            lat: location.lat,
            lng: location.lng,
          )
          .first;
      nearbyPaths = results;
      if (location.denied) {
        pathsError = 'Location permission is needed for better matches.';
      }
    } catch (e) {
      pathsError = 'Could not load nearby people. Please try again.';
    } finally {
      pathsLoading = false;
      notifyListeners();
    }
  }

  Future<String> sendPathsInvite({
    required String receiverUid,
    required String intent,
  }) {
    return _repository.sendPathsInvite(
      receiverUid: receiverUid,
      intent: intent,
    );
  }

  Stream<PathsInvite> inviteStatus(String inviteId) =>
      _repository.inviteStatus(inviteId);

  // Blinds
  Future<void> enqueueBlind({
    required String intent,
    required String distanceBucket,
    List<String>? interests,
    DateTime? availableUntil,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // In test mode or unauth, just simulate success for UI
      if (kDebugMode) print('Simulating enqueue for unauth user');
      return;
    }
    
    await _repository.enqueueBlind(BlindQueueEntry(
      userId: uid,
      intent: intent,
      distanceBucket: distanceBucket,
      interests: interests,
      availableUntil: availableUntil,
    ));
    _isSearchingBlind = true;
    notifyListeners();
  }

  Future<void> dequeueBlind() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _repository.dequeueBlind(uid);
  }



  void finishMatchSuccessToChat() {
    if (activeProfile == null && matches.isNotEmpty) {
      activeProfile = matches.last.profile;
    }
    replaceTop(AppStage.chat);
  }

  void finishMatchSuccessToPool() {
    activeProfile = null;
    _pendingInviteSlot = null;
    replaceStack(<AppStage>[AppStage.dailyPool]);
  }

  bool get isSignedIn => FirebaseAuth.instance.currentUser != null;

  int get currentTabIndex {
    switch (current) {
      case AppStage.dailyPool:
        return 0;
      case AppStage.chatList:
      case AppStage.chat:
        return 1;
      case AppStage.paths:
        return 2;
      case AppStage.blinds:
        return 3;
      case AppStage.profileSettings:
      case AppStage.profilePreview:
      case AppStage.editProfile:
        return 4;
      default:
        return 0;
    }
  }

  void openChatList() {
    replaceStack(<AppStage>[AppStage.chatList]);
  }

  void openChatDetail(VibeProfile profile, {String? chatId}) {
    activeProfile = profile;
    activeChatId = chatId ?? activeChatId ?? profile.uid;
    replaceStack(<AppStage>[AppStage.chat]);
  }



  void openPaths() {
    replaceStack(<AppStage>[AppStage.paths]);
    if (!pathsLoading && nearbyPaths.isEmpty) {
      unawaited(
        refreshPaths(
          radiusKm: lastPathsRadiusKm,
          intents: lastPathsIntents,
        ),
      );
    }
  }

  void openBlinds() {
    replaceStack(<AppStage>[AppStage.blinds]);
  }

  void openBlindChat(BlindSession session) {
    activeBlindSession = session;
    _activeBlindSub?.cancel();
    _activeBlindSub = _repository.blindSessionUpdates(session.id).listen((updated) {
       activeBlindSession = updated;
       if (updated.phase == 'reveal') {
         // Optionally fetch real profile now
       }
       notifyListeners();
    });

    final otherUid = session.userA == FirebaseAuth.instance.currentUser?.uid 
      ? session.userB : session.userA;
      
    activeProfile = VibeProfile(
      uid: otherUid,
      name: 'Mystery Match',
      age: 0,
      imageUrl: '',
      compatibility: 0,
      bio: 'Anonymous chat session',
      distance: 'Nearby',
    );
    activeChatId = session.id;
    replaceStack(<AppStage>[AppStage.chat]);
  }

  void openHome() {
    replaceStack(<AppStage>[AppStage.dailyPool]);
  }

  void openChats() {
    replaceStack(<AppStage>[AppStage.chatList]);
  }

  void openTab(int index) {
    if (!isSignedIn) {
      replaceStack(<AppStage>[AppStage.authGate]);
      return;
    }
    // Profile completion is no longer a blocker - users can browse Tonight without completing
    // The profile completion prompt is shown on the Profile page instead
    if (isSendingAction) return; // debounce cross-tab while actions in flight
    switch (index) {
      case 0:
        openHome();
        break;
      case 1:
        openChats();
        break;
      case 2:
        openPaths();
        break;
      case 3:
        openBlinds();
        break;
      case 4:
        openProfileSettings();
        break;
    }
  }

  void openProfileSettings() {
    replaceStack(<AppStage>[AppStage.profileSettings]);
  }

  Future<void> signOut() async {
    activeProfile = null;
    activeChatId = null;
    _pendingInviteSlot = null;
    _poolIndex = 0;
    matches.clear();
    for (var i = 0; i < photoSlots.length; i++) {
      photoSlots[i] = const PhotoSlot();
    }
    await _prefs?.remove(_kOnboardingCompleteKey);
    await _blindSessionSub?.cancel();
    _blindSessionSub = null;
    await _meltInviteSub?.cancel();
    _meltInviteSub = null;
    replaceStack(<AppStage>[AppStage.authGate]);
  }

  @override
  void dispose() {
    _blindSessionSub?.cancel();
    _meltInviteSub?.cancel();
    super.dispose();
  }

  Future<void> upgradeToPremium() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    // Optimistic update
    isPremium = true;
    notifyListeners();

    try {
      await _repository.updateProfile(uid: uid, isPremium: true);
    } catch (_) {
      isPremium = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> uploadPhotoForSlot(int index) async {
    if (index < 0 || index >= photoSlots.length) {
      throw RangeError.index(index, photoSlots);
    }
    photoSlots[index] = photoSlots[index].copyWith(
      status: PhotoSlotStatus.uploading,
    );
    notifyListeners();
    try {
      final uploaded = await _photoUploadService.pickAndUpload(
        slotIndex: index,
      );
      photoSlots[index] = photoSlots[index].copyWith(
        status: PhotoSlotStatus.uploaded,
        imageUrl: uploaded.url,
        localPath: uploaded.localPath,
      );
      await _persistPhotosIfPossible();
      notifyListeners();
    } on PhotoUploadException catch (error) {
      photoSlots[index] = photoSlots[index].copyWith(
        status: PhotoSlotStatus.failed,
        error: error.message,
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _persistPhotosIfPossible() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final uploadedUrls = photoSlots
          .where((p) => p.status == PhotoSlotStatus.uploaded && p.imageUrl != null)
          .map((p) => p.imageUrl!)
          .toList();
      if (uploadedUrls.isEmpty) return;
      await _repository.updateProfilePhotos(uid: uid, photoUrls: uploadedUrls);
    } catch (_) {
      // Ignore persistence errors; user photos remain locally available.
      // This also handles test environments where Firebase isn't initialized.
    }
  }

  void _loadSettings() {
    notificationsEnabled = _prefs?.getBool('notifications_enabled') ?? true;
    onlineStatusEnabled = _prefs?.getBool('online_status_enabled') ?? true;
    readReceiptsEnabled = _prefs?.getBool('read_receipts_enabled') ?? false;
    notifyListeners();
  }

  Future<void> _loadProfilePhotos() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final profile = await _repository.fetchProfile(uid);
      final photos = profile?.photoUrls ?? const [];
      if (photos.isEmpty) return;
      for (var i = 0; i < photoSlots.length; i++) {
        if (i < photos.length) {
          photoSlots[i] = photoSlots[i].copyWith(
            status: PhotoSlotStatus.uploaded,
            imageUrl: photos[i],
          );
        } else {
          photoSlots[i] = const PhotoSlot();
        }
      }
      notifyListeners();
    } catch (_) {
      // ignore hydrate errors
    }
  }

  Future<void> refreshProfile() async {
    await _loadProfileBasics();
    notifyListeners();
  }

  Future<void> _loadProfileBasics() async {
    final user = FirebaseAuth.instance.currentUser;
    profileName = user?.displayName ?? profileName ?? 'Freezme member';
    profileEmail = user?.email;
    profilePhotoUrl = user?.photoURL;
    hasBio = false;
    hasPreferences = false;
    notifyListeners();
    if (user == null) return;
    try {
      final profile = await _repository.fetchProfile(user.uid);
      if (profile != null) {
        fullProfile = profile;
        profileName = profile.name.isNotEmpty ? profile.name : profileName;
        if (profile.photoUrls.isNotEmpty) {
          profilePhotoUrl = profile.photoUrls.first;
        }
        hasBio = profile.bio.trim().isNotEmpty;
        // Heuristic until prefs are modeled: mark preferences set if we have age
        // and a non-empty distance string.
        hasPreferences =
            (profile.age > 0) && profile.distance.trim().isNotEmpty;
        isPremium = profile.isPremium;
      }
      notifyListeners();
    } catch (_) {
      // silently ignore profile fetch issues
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
    notifyListeners();
    await _prefs?.setBool('notifications_enabled', value);
  }

  Future<void> setOnlineStatusEnabled(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final previous = onlineStatusEnabled;
    onlineStatusEnabled = value;
    notifyListeners();
    await _prefs?.setBool('online_status_enabled', value);
    if (uid != null) {
      try {
        await _repository.updateOnlineStatus(uid, value);
      } catch (_) {
        onlineStatusEnabled = previous;
        notifyListeners();
      }
    }
  }

  Future<void> setReadReceiptsEnabled(bool value) async {
    readReceiptsEnabled = value;
    notifyListeners();
    await _prefs?.setBool('read_receipts_enabled', value);
  }

  Future<void> setBioFilled(bool value) async {
    hasBio = value;
    notifyListeners();
  }

  Future<void> setPreferencesSet(bool value) async {
    hasPreferences = value;
    notifyListeners();
  }

  Future<bool> sendMeltChatInvite(VibeProfile profile, String slotLabel) async {
    try {
      await _meltChatService.sendInvite(
        targetUid: profile.uid,
        slotLabel: slotLabel,
      );
      _pendingInviteSlot = slotLabel;
      // Video call removed - invite sent
      return true;
    } catch (_) {
      return false;
    }
  }



  void returnToPool({bool resetIndex = false}) {
    if (resetIndex) {
      restartDailyPool();
    }
    replaceStack(<AppStage>[AppStage.dailyPool]);
  }

  Future<void> likeCurrent({bool superLike = false}) async {
    if (dailyProfiles.isEmpty || isSendingAction) return;
    isSendingAction = true;
    notifyListeners();
    final profile = currentProfile;
    try {
      await _repository.likeProfile(profile.uid);
      if (superLike && superVibesRemaining > 0) {
        superVibesRemaining -= 1;
      }
    } catch (_) {
      // swallow for now; could surface an error
    } finally {
      isSendingAction = false;
      skipProfile();
    }
  }

  Future<void> passCurrent() async {
    if (dailyProfiles.isEmpty || isSendingAction) return;
    isSendingAction = true;
    notifyListeners();
    final profile = currentProfile;
    try {
      await _repository.skipProfile(profile.uid);
    } catch (_) {
      // ignore for now
    } finally {
      isSendingAction = false;
      skipProfile();
    }
  }

  static List<VibeProfile> _mockProfiles() => const <VibeProfile>[
    VibeProfile(
      uid: 'profile_1',
      id: 1,
      name: 'Emma',
      age: 24,
      imageUrl:
          'https://images.unsplash.com/photo-1546961329-78bef0414d7c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx5b3VuZyUyMHdvbWFuJTIwcG9ydHJhaXR8ZW58MXx8fHwxNzYwOTQ2MDQ5fDA&ixlib=rb-4.1.0&q=80&w=1080',
      compatibility: 92,
      bio:
          'Adventure seeker | Coffee addict | Let\'s explore the city together ☕',
      distance: '2 km away',
    ),
    VibeProfile(
      uid: 'profile_2',
      id: 2,
      name: 'Alex',
      age: 27,
      imageUrl:
          'https://images.unsplash.com/flagged/photo-1596479042555-9265a7fa7983?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHx5b3VuZyUyMG1hbiUyMHBvcnRyYWl0fGVufDF8fHx8MTc2MDkzNjI2MHww&ixlib=rb-4.1.0&q=80&w=1080',
      compatibility: 88,
      bio:
          'Fitness enthusiast | Foodie | Looking for meaningful connections 💪',
      distance: '5 km away',
    ),
    VibeProfile(
      uid: 'profile_3',
      id: 3,
      name: 'Sophie',
      age: 26,
      imageUrl:
          'https://images.unsplash.com/photo-1591969851586-adbbd4accf81?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHxyb21hbnRpYyUyMGNvdXBsZXxlbnwxfHx8fDE3NjA5Nzg1Nzh8MA&ixlib=rb-4.1.0&q=80&w=1080',
      compatibility: 85,
      bio:
          'Artist at heart | Music lover | Deep conversations over small talk 🎨',
      distance: '3 km away',
    ),
  ];
}

enum PhotoSlotStatus { empty, uploading, uploaded, failed }

class PhotoSlot {
  const PhotoSlot({
    this.status = PhotoSlotStatus.empty,
    this.imageUrl,
    this.localPath,
    this.error,
  });

  final PhotoSlotStatus status;
  final String? imageUrl;
  final String? localPath;
  final String? error;

  PhotoSlot copyWith({
    PhotoSlotStatus? status,
    String? imageUrl,
    String? localPath,
    String? error,
  }) {
    return PhotoSlot(
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      localPath: localPath ?? this.localPath,
      error: error ?? this.error,
    );
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

class FreezmeApp extends StatefulWidget {
  const FreezmeApp({super.key, this.controllerBuilder});

  final Future<AppFlowController> Function()? controllerBuilder;

  @override
  State<FreezmeApp> createState() => _FreezmeAppState();
}

class _FreezmeAppState extends State<FreezmeApp> {
  AppFlowController? _controller;

  @override
  void initState() {
    super.initState();
    final builder = widget.controllerBuilder ?? AppFlowController.create;
    builder().then((controller) {
      if (mounted) {
        setState(() {
          _controller = controller;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    final router = FreezmeRouter(_controller!);

    return AppFlowScope(
      controller: _controller!,
      child: MaterialApp.router(
        title: 'Freezme',
        debugShowCheckedModeBanner: false,
        theme: FreezmeTheme.build(),
        routerConfig: router.router,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'), // English
        ],
      ),
    );
  }
}

// ============================================================================
// UI Pages
// ============================================================================






Widget _surfaceCard({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
      border: Border.all(color: FreezmeColors.border),
    ),
    child: child,
  );
}




class DeveloperPreviewScreen extends StatelessWidget {
  const DeveloperPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    final actions = [
      (
        label: 'Auth Gate',
        action: () => flow.replaceStack(<AppStage>[AppStage.authGate]),
      ),
      (
        label: 'Onboarding',
        action: () => flow.replaceStack(<AppStage>[AppStage.onboarding]),
      ),
      (
        label: 'Daily Vibe Pool',
        action: () => flow.replaceStack(<AppStage>[AppStage.dailyPool]),
      ),
      (
        label: 'Match Success',
        action: () {
          flow.replaceStack(<AppStage>[AppStage.matchSuccess]);
          flow.activeProfile = flow.currentProfile;
        },
      ),
      (
        label: 'Chat Screen',
        action: () {
          flow.replaceStack(<AppStage>[AppStage.dailyPool]);
          flow.openChat(flow.currentProfile);
        },
      ),
      (
        label: 'Profile Settings',
        action: () {
          flow.replaceStack(<AppStage>[AppStage.dailyPool]);
          flow.openProfileSettings();
        },
      ),
      (
        label: 'Profile Preview',
        action: () {
          flow.replaceStack(<AppStage>[AppStage.profilePreview]);
        },
      ),
      (
        label: 'Daily Recap',
        action: () {
          flow.replaceStack(<AppStage>[AppStage.dailyRecap]);
        },
      ),
      (
        label: 'Freezme+',
        action: () {
          flow.replaceStack(<AppStage>[AppStage.freezmePlus]);
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Design Previews'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: flow.closeDeveloperMenu,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [FreezmeColors.background, Color(0xFFE7E9FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final action in actions)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7A6ACD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: action.action,
                    child: Text(action.label),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showFreezeModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: FreezeModalContent(
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      );
    },
  );
}

class FreezeModalContent extends StatelessWidget {
  const FreezeModalContent({super.key, required this.onClose});

  final VoidCallback onClose;

  static final _options = [
    (
      icon: Icons.person_outline,
      title: 'Freeze my profile',
      description: 'Hide your profile for 24 hours',
      emoji: '🙈',
      premium: false,
    ),
    (
      icon: Icons.ac_unit,
      title: 'Pause this match',
      description: 'Take a break from this connection',
      emoji: '⏸️',
      premium: false,
    ),
    (
      icon: Icons.message_outlined,
      title: 'Freeze chat',
      description: 'Pause notifications for 24 hours',
      emoji: '🔕',
      premium: false,
    ),
    (
      icon: Icons.access_time,
      title: 'Extend Freeze',
      description: 'Premium: Freeze for up to 7 days',
      emoji: '⭐',
      premium: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [FreezmeColors.primary, FreezmeColors.secondary],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
                Row(
                  children: const [
                    Icon(Icons.ac_unit, color: Colors.white, size: 48),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Take a Breather\nWe\'ll hold your vibe safely 💜',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                for (final option in _options) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FreezmeColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: FreezmeColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 48,
                            width: 48,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  FreezmeColors.primary,
                                  FreezmeColors.secondary,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(option.icon, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      option.title,
                                      style: const TextStyle(
                                        color: FreezmeColors.neutral,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(option.emoji),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  option.description,
                                  style: const TextStyle(
                                    color: FreezmeColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                                if (option.premium) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          FreezmeColors.secondary,
                                          FreezmeColors.accent,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(999),
                                      ),
                                    ),
                                    child: const Text(
                                      'Freezme+ Only',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: FreezmeColors.surfaceAlt,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Taking breaks is healthy 💜 Your connections will be here when you\'re ready',
                textAlign: TextAlign.center,
                style: TextStyle(color: FreezmeColors.primary, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
