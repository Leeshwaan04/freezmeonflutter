import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'models/chat_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'data/firestore_freezme_repository.dart';
import 'data/freezme_repository.dart';
import 'models/paths.dart';
import 'services/location_service.dart';
import 'services/melt_chat_service.dart';
import 'services/photo_upload_service.dart';

import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const FreezmeApp());
}

enum AppStage {
  splash,
  authGate,
  onboarding,
  compatibilityQuiz,
  dailyPool,
  chatList,
  feed,
  paths,
  blinds,
  videoDate,
  matchSuccess,
  chat,
  profileSettings,
  profilePreview,
  dailyRecap,
  freezmePlus,
  developerMenu,
}

class VibeProfile {
  const VibeProfile({
    required this.id,
    String? uid,
    required this.name,
    required this.age,
    required this.imageUrl,
    required this.compatibility,
    required this.bio,
    required this.distance,
  }) : uid = uid ?? 'profile_$id';

  final String uid;
  final int id;
  final String name;
  final int age;
  final String imageUrl;
  final int compatibility;
  final String bio;
  final String distance;
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

  AppFlowController._(
    this._prefs, {
    PhotoUploadService? photoUploadService,
    MeltChatService? meltChatService,
    FreezmeRepository? repository,
    LocationService? locationService,
  }) : _photoUploadService = photoUploadService ?? MockPhotoUploadService(),
       _meltChatService = meltChatService ?? MockMeltChatService(),
       _repository = repository ?? FirestoreFreezmeRepository(),
       _locationService = locationService ?? LocationService(),
       photoSlots = List<PhotoSlot>.generate(6, (_) => const PhotoSlot()),
       dailyProfiles = _mockProfiles() {
    _hydrate();
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
  }) {
    return AppFlowController._(
      prefs,
      photoUploadService: photoUploadService,
      meltChatService: meltChatService,
      repository: repository,
      locationService: locationService,
    );
  }

  final SharedPreferences? _prefs;
  final PhotoUploadService _photoUploadService;
  final MeltChatService _meltChatService;
  final FreezmeRepository _repository;
  final LocationService _locationService;
  final List<AppStage> _stack = <AppStage>[AppStage.splash];
  final List<AppMatch> matches = <AppMatch>[];
  final List<VibeProfile> dailyProfiles;
  final List<PhotoSlot> photoSlots;
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

  List<AppStage> get stack => List.unmodifiable(_stack);
  AppStage get current => _stack.last;
  int get poolIndex => _poolIndex;
  int get vibesRemaining => math.max(0, dailyProfiles.length - _poolIndex - 1);
  List<PhotoSlot> get currentPhotoSlots => List.unmodifiable(photoSlots);

  VibeProfile get currentProfile =>
      dailyProfiles[_poolIndex.clamp(0, dailyProfiles.length - 1)];

  int get remainingProfiles =>
      math.max(0, dailyProfiles.length - _poolIndex - 1);

  void _hydrate() {
    final completed = _prefs?.getBool(_kOnboardingCompleteKey) ?? false;
    _stack
      ..clear()
      ..add(completed ? AppStage.dailyPool : AppStage.splash);
    if (!completed) {
      _poolIndex = 0;
    }
    unawaited(_loadProfilePhotos());
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

  void completeSplash() => replaceStack(<AppStage>[AppStage.authGate]);

  void startOnboarding() {
    _prefs?.remove(_kOnboardingCompleteKey);
    _poolIndex = 0;
    replaceStack(<AppStage>[AppStage.onboarding]);
  }

  void beginCompatibilityQuiz() {
    // Skip compatibility quiz and go straight to the daily pool.
    finishCompatibilityQuiz();
  }

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

  void openFreezmePlus() => pushIfMissing(AppStage.freezmePlus);

  void openDeveloperMenu() => pushIfMissing(AppStage.developerMenu);

  void closeDeveloperMenu() => pop();

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


  void startVideoDate(VibeProfile profile, {String? scheduledSlot}) {
    activeProfile = profile;
    _pendingInviteSlot = scheduledSlot;
    pushIfMissing(AppStage.videoDate);
  }

  void completeVideoDate({bool success = true}) {
    if (!success) {
      pop();
      return;
    }
    if (activeProfile != null) {
      matches.add(
        AppMatch(
          profile: activeProfile!,
          matchedAt: DateTime.now(),
          scheduledSlot: _pendingInviteSlot,
        ),
      );
    }
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
    _pendingInviteSlot = null;
    replaceStack(<AppStage>[AppStage.dailyPool]);
  }

  void openChatList() {
    replaceStack(<AppStage>[AppStage.chatList]);
  }

  void openChatDetail(VibeProfile profile, {String? chatId}) {
    activeProfile = profile;
    activeChatId = chatId ?? activeChatId ?? profile.uid;
    replaceStack(<AppStage>[AppStage.chat]);
  }

  void openFeed() {
    replaceStack(<AppStage>[AppStage.feed]);
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
    replaceStack(<AppStage>[AppStage.authGate]);
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final uploadedUrls = photoSlots
        .where((p) => p.status == PhotoSlotStatus.uploaded && p.imageUrl != null)
        .map((p) => p.imageUrl!)
        .toList();
    if (uploadedUrls.isEmpty) return;
    try {
      await _repository.updateProfilePhotos(uid: uid, photoUrls: uploadedUrls);
    } catch (_) {
      // Ignore persistence errors; user photos remain locally available.
    }
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

  Future<bool> sendMeltChatInvite(VibeProfile profile, String slotLabel) async {
    try {
      await _meltChatService.sendInvite(
        targetUid: profile.uid,
        slotLabel: slotLabel,
      );
      _pendingInviteSlot = slotLabel;
      pushIfMissing(AppStage.videoDate);
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
      id: 2,
      name: 'Alex',
      age: 27,
      imageUrl:
          'https://images.unsplash.com/flagged/photo-1596479042555-9265a7fa7983?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx5b3VuZyUyMG1hbiUyMHBvcnRyYWl0fGVufDF8fHx8MTc2MDkzNjI2MHww&ixlib=rb-4.1.0&q=80&w=1080',
      compatibility: 88,
      bio:
          'Fitness enthusiast | Foodie | Looking for meaningful connections 💪',
      distance: '5 km away',
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

    return AppFlowScope(
      controller: _controller!,
      child: MaterialApp(
        title: 'Freezme',
        debugShowCheckedModeBanner: false,
        theme: FreezmeTheme.build(),
        home: const FlowNavigator(),
      ),
    );
  }
}

class FlowNavigator extends StatelessWidget {
  const FlowNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    return AnimatedBuilder(
      animation: flow,
      builder: (context, _) {
        final pages = <Page<dynamic>>[
          for (final stage in flow.stack)
            MaterialPage<dynamic>(
              key: ValueKey<AppStage>(stage),
              child: _buildStage(context, stage),
            ),
        ];

        return Navigator(
          pages: pages,
          // ignore: deprecated_member_use
          onPopPage: (route, result) {
            if (!route.didPop(result)) {
              return false;
            }
            flow.pop();
            return true;
          },
        );
      },
    );
  }

  Widget _buildStage(BuildContext context, AppStage stage) {
    switch (stage) {
      case AppStage.splash:
        return const SplashScreen();
      case AppStage.authGate:
        return const AuthGatePage();
      case AppStage.onboarding:
        return const OnboardingFlowPage();
      case AppStage.compatibilityQuiz:
        return const CompatibilityQuizPage();
      case AppStage.dailyPool:
        return const DailyVibePoolPage();
      case AppStage.chatList:
        return const ChatListPage();
      case AppStage.feed:
        return const DailyVibePoolPage();
      case AppStage.paths:
        return const PathsPage();
      case AppStage.blinds:
        return const BlindsPage();
      case AppStage.videoDate:
        return const VideoDatePage();
      case AppStage.matchSuccess:
        return const MatchSuccessPage();
      case AppStage.chat:
        return const ChatScreenPage();
      case AppStage.profileSettings:
        return const ProfileSettingsPage();
      case AppStage.profilePreview:
        return const ProfilePreviewPage();
      case AppStage.dailyRecap:
        return const DailyRecapPage();
      case AppStage.freezmePlus:
        return const FreezeMePlusPage();
      case AppStage.developerMenu:
        return const DeveloperPreviewScreen();
    }
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _rotationController;
  late final AnimationController _textController;
  late final AnimationController _backgroundController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _textOffsetAnimation;
  late final Animation<double> _textOpacityAnimation;
  late final Animation<Color?> _gradientStart;
  late final Animation<Color?> _gradientEnd;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOut,
    );

    _opacityAnimation = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOut,
    );

    _textOpacityAnimation = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );

    _textOffsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _introController.forward();
    _rotationController.repeat();
    _backgroundController.repeat(reverse: true);

    _gradientStart =
        ColorTween(
          begin: FreezmeColors.surface,
          end: FreezmeColors.surfaceAlt,
        ).animate(
          CurvedAnimation(
            parent: _backgroundController,
            curve: Curves.easeInOut,
          ),
        );

    _gradientEnd =
        ColorTween(
          begin: FreezmeColors.surfaceAlt,
          end: FreezmeColors.surface,
        ).animate(
          CurvedAnimation(
            parent: _backgroundController,
            curve: Curves.easeInOut,
          ),
        );

    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _textController.forward();
      }
    });

    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        AppFlowScope.of(context, listen: false).completeSplash();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _introController.dispose();
    _rotationController.dispose();
    _textController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _backgroundController,
        builder: (context, _) {
          final gradientStart = _gradientStart.value ?? FreezmeColors.surface;
          final gradientEnd = _gradientEnd.value ?? FreezmeColors.surfaceAlt;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gradientStart, gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                _FloatingOrbs(progress: _backgroundController.value),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _opacityAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: RotationTransition(
                            turns: Tween<double>(begin: 0, end: 1).animate(
                              CurvedAnimation(
                                parent: _rotationController,
                                curve: Curves.linear,
                              ),
                            ),
                            child: const FreezmeLogo(
                              size: LogoSize.lg,
                              variant: LogoVariant.gradient,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      FadeTransition(
                        opacity: _textOpacityAnimation,
                        child: SlideTransition(
                          position: _textOffsetAnimation,
                          child: Column(
                            children: [
                              Text(
                                'FREEZME',
                                style: FreezmeTypography.title.copyWith(
                                  letterSpacing: 1.2,
                                  color: FreezmeColors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Where Compatibility Meets Real Connection 💜',
                                textAlign: TextAlign.center,
                                style: FreezmeTypography.subtitle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FloatingOrbs extends StatelessWidget {
  const _FloatingOrbs({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final angle = progress * math.pi * 2;
    final secondaryAngle = (progress + 0.35) * math.pi * 2;
    final tertiaryAngle = (progress + 0.7) * math.pi * 2;

    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned(
              top: 90 + math.sin(angle) * 24,
              left: -60 + math.cos(angle) * 30,
              child: const _GlowingOrb(
                size: 220,
                colors: [FreezmeColors.secondary, FreezmeColors.surfaceAlt],
                opacity: 0.35,
              ),
            ),
            Positioned(
              bottom: 140 + math.cos(secondaryAngle) * 28,
              right: -50 + math.sin(secondaryAngle) * 32,
              child: const _GlowingOrb(
                size: 180,
                colors: [FreezmeColors.accent, FreezmeColors.surface],
                opacity: 0.3,
              ),
            ),
            Positioned(
              top: 200 + math.sin(tertiaryAngle) * 36,
              right: 80 + math.cos(tertiaryAngle) * 24,
              child: const _GlowingOrb(
                size: 140,
                colors: [FreezmeColors.primary, FreezmeColors.surfaceAlt],
                opacity: 0.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowingOrb extends StatelessWidget {
  const _GlowingOrb({
    required this.size,
    required this.colors,
    required this.opacity,
  });

  final double size;
  final List<Color> colors;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            colors.first.withValues(alpha: opacity),
            colors.last.withValues(alpha: 0.05),
          ],
          stops: const [0, 1],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: opacity),
            blurRadius: size * 0.35,
            spreadRadius: size * 0.08,
          ),
        ],
      ),
    );
  }
}

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  bool _busy = false;
  String? _authError;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      setState(() {
        _authError = 'Could not open link. Please try again.';
      });
    }
  }

  Future<void> _start(AppFlowController flow) async {
    if (_busy) return;
    setState(() => _busy = true);
    setState(() => _authError = null);
    try {
      flow.startOnboarding();
    } catch (_) {
      setState(() {
        _authError = 'Sign-in failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: FreezmeInsets.pageGutter,
                vertical: FreezmeInsets.sectionSpacing,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FreezmeLogo(
                      size: LogoSize.lg,
                      variant: LogoVariant.gradient,
                    ),
                    const SizedBox(height: FreezmeInsets.sectionSpacing * 1.2),
                    const Text(
                      'Intentional dating for soulful matches',
                      style: FreezmeTypography.display,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Daily pools, mindful pacing, and video vibes that keep connections real.',
                      style: FreezmeTypography.bodyMuted,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: FreezmeInsets.sectionSpacing),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: const [
                        _HighlightPill(
                          icon: Icons.favorite_border,
                          label: 'Curated daily matches',
                        ),
                        _HighlightPill(
                          icon: Icons.videocam_outlined,
                          label: '1:1 video vibes',
                        ),
                        _HighlightPill(
                          icon: Icons.health_and_safety_outlined,
                          label: 'Accountability-first safety',
                        ),
                      ],
                    ),
                    const SizedBox(height: FreezmeInsets.sectionSpacing * 1.2),
                    _AuthButton(
                      label: _busy ? 'Please wait…' : 'Continue with Apple',
                      icon: Icons.apple,
                      gradient: FreezmeGradients.primary,
                      foreground: Colors.white,
                      enabled: !_busy,
                      onTap: () => _start(flow),
                    ),
                    const SizedBox(height: FreezmeInsets.elementSpacing),
                    _AuthButton(
                      label: _busy ? 'Loading…' : 'Continue with Google',
                      icon: Icons.g_mobiledata,
                      foreground: FreezmeColors.primary,
                      background: Colors.white,
                      border: const BorderSide(
                        color: FreezmeColors.primary,
                        width: 2,
                      ),
                      enabled: !_busy,
                      onTap: () => _start(flow),
                    ),
                    const SizedBox(height: FreezmeInsets.elementSpacing),
                    _AuthButton(
                      label: _busy ? 'Loading…' : 'Continue with Email',
                      icon: Icons.mail_outline,
                      gradient: FreezmeGradients.primary,
                      foreground: Colors.white,
                      enabled: !_busy,
                      onTap: () => _start(flow),
                    ),
                    const SizedBox(height: FreezmeInsets.sectionSpacing),
                    if (_authError != null) ...[
                      Text(
                        _authError!,
                        style: const TextStyle(
                          color: FreezmeColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: FreezmeInsets.elementSpacing / 2),
                    ],
                    const Text(
                      'Your vibe begins with one tap 💫',
                      style: FreezmeTypography.bodyMuted,
                    ),
                    const SizedBox(height: FreezmeInsets.elementSpacing),
                    _TermsRow(
                      onTerms: () => _launchUrl('https://freezme.app/terms'),
                      onPrivacy: () =>
                          _launchUrl('https://freezme.app/privacy'),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: FreezmeInsets.sectionSpacing),
                      TextButton(
                        onPressed: flow.openDeveloperMenu,
                        child: const Text('Open Developer Preview'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HighlightPill extends StatelessWidget {
  const _HighlightPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FreezmeColors.border),
        boxShadow: [
          BoxShadow(
            color: FreezmeColors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: FreezmeColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: FreezmeTypography.body.copyWith(
              color: FreezmeColors.neutral,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.onTerms, required this.onPrivacy});

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'By continuing you agree to our ',
        style: FreezmeTypography.bodyMuted.copyWith(fontSize: 13),
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: onTerms,
              child: const Text(
                'Terms',
                style: TextStyle(
                  color: FreezmeColors.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const TextSpan(text: ' and '),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: onPrivacy,
              child: const Text(
                'Privacy Policy',
                style: TextStyle(
                  color: FreezmeColors.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.background,
    this.foreground,
    this.gradient,
    this.border,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? background;
  final Color? foreground;
  final Gradient? gradient;
  final BorderSide? border;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textColor = foreground ?? Colors.white;
    final borderSide = border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            gradient: enabled ? gradient : null,
            color: gradient == null
                ? (enabled ? background : background?.withValues(alpha: 0.5))
                : null,
            borderRadius: BorderRadius.circular(999),
            border: borderSide != null
                ? Border.fromBorderSide(borderSide)
                : null,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: FreezmeInsets.elementSpacing,
            vertical: 18,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: enabled ? textColor : textColor.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: FreezmeTypography.button.copyWith(
                  color: enabled ? textColor : textColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BottomNavItem(
              icon: Icons.chat_bubble_outline,
              label: 'Chats',
              active: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _BottomNavItem(
              icon: Icons.favorite_border,
              label: 'Feed',
              active: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            _BottomNavItem(
              icon: Icons.route_outlined,
              label: 'Paths',
              active: currentIndex == 2,
              onTap: () => onTap(2),
            ),
            _BottomNavItem(
              icon: Icons.bolt_outlined,
              label: 'Blinds',
              active: currentIndex == 3,
              onTap: () => onTap(3),
            ),
            _BottomNavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              active: currentIndex == 4,
              onTap: () => onTap(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? FreezmeColors.primary : FreezmeColors.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

class OnboardingFlowPage extends StatefulWidget {
  const OnboardingFlowPage({super.key});

  @override
  State<OnboardingFlowPage> createState() => _OnboardingFlowPageState();
}

class _OnboardingFlowPageState extends State<OnboardingFlowPage> {
  int _step = 1;
  String? _selectedIntent;
  final ImagePicker _picker = ImagePicker();
  final List<_PhotoSlot> _photoSlots = List.generate(
    6,
    (_) => const _PhotoSlot.empty(),
  );
  String? _photoError;
  final TextEditingController _bioController = TextEditingController();
  int _age = 25;
  int _distanceKm = 50;
  String? _profileError;
  final Set<String> _selectedInterests = <String>{};

  final List<({String id, String label, String emoji})> _intents = const [
    (id: 'meaningful', label: 'Meaningful connection', emoji: '💜'),
    (id: 'exploring', label: 'Just exploring', emoji: '✨'),
    (id: 'see', label: 'Let\'s see where it goes', emoji: '🌟'),
  ];

  int get _readyCount =>
      _photoSlots.where((slot) => slot.status == _PhotoStatus.ready).length;

  void _handleNext(AppFlowController flow) {
    if (_step == 2 && _readyCount < 3) {
      setState(() {
        _photoError = 'Add at least 3 photos to continue.';
      });
      return;
    }
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    if (!_validateProfile()) return;
    flow.beginCompatibilityQuiz();
  }

  bool _validateProfile() {
    final bio = _bioController.text.trim();
    if (bio.length < 10) {
      setState(() => _profileError = 'Tell us a bit more (min 10 characters).');
      return false;
    }
    if (_selectedInterests.length < 2) {
      setState(() => _profileError = 'Pick at least 2 interests.');
      return false;
    }
    setState(() => _profileError = null);
    return true;
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final progress = _step / 3;

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
                      'Step $_step of 3',
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
                      SizedBox(
                        height: 52,
                        width: 52,
                        child: OutlinedButton(
                          onPressed: () => setState(() => _step--),
                          style: FreezmeButtons.secondaryOutlined,
                          child: const Icon(Icons.chevron_left),
                        ),
                      )
                    else
                      const SizedBox(width: 0, height: 0),
                    const SizedBox(width: FreezmeInsets.elementSpacing / 1.5),
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            (_step == 1 && _selectedIntent == null) ||
                                (_step == 2 && _readyCount < 3)
                            ? null
                            : () => _handleNext(flow),
                        style: FreezmeButtons.primaryFilled,
                        child: Text(_step == 3 ? 'Continue' : 'Next'),
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
            for (final intent in _intents) ...[
              GestureDetector(
                onTap: () => setState(() => _selectedIntent = intent.id),
                child: Container(
                  margin: const EdgeInsets.only(
                    bottom: FreezmeInsets.elementSpacing,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: FreezmeInsets.elementSpacing,
                    vertical: FreezmeInsets.sectionSpacing / 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedIntent == intent.id
                        ? FreezmeColors.primary
                        : Colors.white,
                    borderRadius: BorderRadius.circular(
                      FreezmeInsets.cardRadius,
                    ),
                    border: Border.all(
                      color: _selectedIntent == intent.id
                          ? FreezmeColors.primary
                          : FreezmeColors.border,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(intent.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: FreezmeInsets.elementSpacing),
                      Expanded(
                        child: Text(
                          intent.label,
                          style: TextStyle(
                            color: _selectedIntent == intent.id
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
            ],
          ],
        );
      case 2:
        return Column(
          key: const ValueKey<int>(2),
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
                  Text(
                    'Add at least 3 photos 📸 • $_readyCount/6 uploaded',
                    style: FreezmeTypography.bodyMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: FreezmeInsets.elementSpacing),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(FreezmeInsets.elementSpacing),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(FreezmeInsets.cardRadius),
                border: Border.all(color: FreezmeColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    color: FreezmeColors.primary,
                  ),
                  const SizedBox(width: FreezmeInsets.elementSpacing / 1.5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Photo tips',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: FreezmeColors.neutral,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Use natural light, no heavy filters, and keep yourself centered so matches see the real you.',
                          style: FreezmeTypography.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_photoError != null) ...[
              const SizedBox(height: FreezmeInsets.elementSpacing / 2),
              Text(
                _photoError!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: FreezmeInsets.sectionSpacing / 1.5),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: FreezmeInsets.elementSpacing,
                mainAxisSpacing: FreezmeInsets.elementSpacing,
                children: List.generate(6, _buildPhotoTile),
              ),
            ),
          ],
        );
      case 3:
      default:
        return SingleChildScrollView(
          key: const ValueKey<int>(3),
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
              const _SectionLabel(
                title: 'Bio',
                helper: 'Share a quick intro (10–180 characters).',
              ),
              const SizedBox(height: FreezmeInsets.elementSpacing / 2),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(FreezmeInsets.cardRadius),
                  border: Border.all(color: FreezmeColors.border),
                ),
                child: TextField(
                  controller: _bioController,
                  maxLines: 5,
                  maxLength: 180,
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: 'What makes you, you?',
                    contentPadding: EdgeInsets.all(16),
                    border: InputBorder.none,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: FreezmeInsets.elementSpacing / 3,
                  right: 4,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_bioController.text.trim().length}/180',
                    style: FreezmeTypography.caption,
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
                        const _SectionLabel(title: 'Age'),
                        Slider(
                          value: _age.toDouble(),
                          min: 18,
                          max: 60,
                          divisions: 42,
                          activeColor: FreezmeColors.primary,
                          label: '$_age',
                          onChanged: (value) =>
                              setState(() => _age = value.round()),
                        ),
                        Text('$_age yrs', style: FreezmeTypography.bodyMuted),
                      ],
                    ),
                  ),
                  const SizedBox(width: FreezmeInsets.elementSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel(title: 'Distance (km)'),
                        Slider(
                          value: _distanceKm.toDouble(),
                          min: 5,
                          max: 200,
                          divisions: 39,
                          activeColor: FreezmeColors.primary,
                          label: '$_distanceKm km',
                          onChanged: (value) =>
                              setState(() => _distanceKm = value.round()),
                        ),
                        Text(
                          '$_distanceKm km max',
                          style: FreezmeTypography.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: FreezmeInsets.sectionSpacing),
              const _SectionLabel(
                title: 'Interests',
                helper: 'Pick at least 2 so we can tailor prompts.',
              ),
              const SizedBox(height: FreezmeInsets.elementSpacing),
              Wrap(
                spacing: FreezmeInsets.elementSpacing,
                runSpacing: FreezmeInsets.elementSpacing,
                children: [
                  for (final interest in const [
                    'Music',
                    'Travel',
                    'Art',
                    'Fitness',
                    'Food',
                    'Books',
                    'Outdoors',
                    'Movies',
                    'Pets',
                  ])
                    _SelectableChip(
                      label: interest,
                      selected: _selectedInterests.contains(interest),
                      onTap: () {
                        setState(() {
                          if (_selectedInterests.contains(interest)) {
                            _selectedInterests.remove(interest);
                          } else {
                            _selectedInterests.add(interest);
                          }
                          _profileError = null;
                        });
                      },
                    ),
                ],
              ),
              if (_profileError != null) ...[
                const SizedBox(height: FreezmeInsets.elementSpacing),
                Text(
                  _profileError!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        );
    }
  }

  Widget _buildPhotoTile(int index) {
    final slot = _photoSlots[index];
    final borderColor = () {
      switch (slot.status) {
        case _PhotoStatus.error:
          return Colors.redAccent;
        case _PhotoStatus.ready:
          return FreezmeColors.primary;
        default:
          return FreezmeColors.border;
      }
    }();

    return GestureDetector(
      key: ValueKey('photo-slot-$index'),
      onTap: () {
        if (slot.status == _PhotoStatus.ready && slot.file != null) {
          _previewPhoto(slot);
        } else {
          _pickPhoto(index);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(FreezmeInsets.cardRadius),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(FreezmeInsets.cardRadius),
                child: slot.file != null
                    ? Image.file(slot.file!, fit: BoxFit.cover)
                    : const SizedBox.shrink(),
              ),
            ),
            if (slot.status == _PhotoStatus.uploading)
              const Center(
                child: SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: FreezmeColors.primary,
                  ),
                ),
              )
            else if (slot.status == _PhotoStatus.ready)
              Positioned(
                top: 8,
                right: 8,
                child: _chip(
                  label: 'Ready',
                  color: Colors.green.shade600,
                  icon: Icons.check,
                ),
              )
            else if (slot.status == _PhotoStatus.error)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.error_outline, color: Colors.redAccent),
                    SizedBox(height: 6),
                    Text(
                      'Tap to retry',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              )
            else
              const Center(
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: FreezmeColors.muted,
                  size: 32,
                ),
              ),
            if (slot.status == _PhotoStatus.ready)
              Positioned(
                top: 8,
                left: 8,
                child: _iconCircle(
                  icon: Icons.open_in_full,
                  onTap: () => _previewPhoto(slot),
                ),
              ),
            if (slot.status == _PhotoStatus.ready ||
                slot.status == _PhotoStatus.error)
              Positioned(
                top: 8,
                right: 8,
                child: _iconCircle(
                  icon: Icons.close,
                  onTap: () => _removePhoto(index),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _iconCircle({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: FreezmeColors.neutral),
      ),
    );
  }

  Widget _chip({required String label, required Color color, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto(int index) async {
    setState(() {
      _photoError = null;
      _photoSlots[index] = _photoSlots[index].copyWith(
        status: _PhotoStatus.uploading,
        error: null,
      );
    });
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
      );
      if (picked == null) {
        setState(() {
          _photoSlots[index] = const _PhotoSlot.empty();
        });
        return;
      }
      final file = File(picked.path);
      setState(() {
        _photoSlots[index] = _photoSlots[index].copyWith(
          status: _PhotoStatus.ready,
          file: file,
        );
      });
    } catch (_) {
      setState(() {
        _photoSlots[index] = _photoSlots[index].copyWith(
          status: _PhotoStatus.error,
          error: 'Could not add photo',
        );
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photoSlots[index] = const _PhotoSlot.empty();
      _photoError = null;
    });
  }

  void _previewPhoto(_PhotoSlot slot) {
    if (slot.file == null || !mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.file(slot.file!, fit: BoxFit.contain),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _iconCircle(
                icon: Icons.close,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PhotoStatus { empty, uploading, ready, error }

class _PhotoSlot {
  final File? file;
  final _PhotoStatus status;
  final String? error;

  const _PhotoSlot({
    required this.file,
    required this.status,
    required this.error,
  });

  const _PhotoSlot.empty()
    : file = null,
      status = _PhotoStatus.empty,
      error = null;

  _PhotoSlot copyWith({File? file, _PhotoStatus? status, String? error}) {
    return _PhotoSlot(
      file: file ?? this.file,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.helper});

  final String title;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: FreezmeColors.neutral,
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(
              top: FreezmeInsets.elementSpacing / 3,
            ),
            child: Text(helper!, style: FreezmeTypography.bodyMuted),
          ),
      ],
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
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
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FreezmeInsets.elementSpacing,
          vertical: FreezmeInsets.elementSpacing / 1.5,
        ),
        decoration: BoxDecoration(
          color: selected ? FreezmeColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(FreezmeInsets.cardRadius),
          border: Border.all(
            color: selected ? FreezmeColors.primary : FreezmeColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: FreezmeColors.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : FreezmeColors.neutral,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class DailyVibePoolPage extends StatefulWidget {
  const DailyVibePoolPage({super.key});

  @override
  State<DailyVibePoolPage> createState() => _DailyVibePoolPageState();
}

class _DailyVibePoolPageState extends State<DailyVibePoolPage> {
  static const List<String> _timeSlots = <String>[
    'Today 7:00 PM',
    'Today 8:00 PM',
    'Tomorrow 6:00 PM',
    'Tomorrow 7:00 PM',
    'Tomorrow 8:00 PM',
  ];

  Future<void> _handleInvite(
    BuildContext context,
    AppFlowController flow,
    VibeProfile profile,
  ) async {
    final slot = await _showInviteDialog(context);
    if (slot != null) {
      flow.startVideoDate(profile, scheduledSlot: slot);
    }
  }

  Future<String?> _showInviteDialog(BuildContext context) async {
    String? selected = _timeSlots.first;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Invite for a Vibe Date?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: FreezmeColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Choose a time for your 20-minute video date:',
                      style: TextStyle(
                        color: FreezmeColors.muted,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final slot in _timeSlots)
                          ChoiceChip(
                            label: Text(slot),
                            selected: selected == slot,
                            onSelected: (_) => setStateDialog(() {
                              selected = slot;
                            }),
                            selectedColor: FreezmeColors.primary,
                            labelStyle: TextStyle(
                              color: selected == slot
                                  ? Colors.white
                                  : FreezmeColors.neutral,
                            ),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: selected == slot
                                    ? FreezmeColors.primary
                                    : FreezmeColors.border,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: FreezmeColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () =>
                          Navigator.of(dialogContext).pop(selected),
                      child: const Text('Confirm Vibe'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    return AnimatedBuilder(
      animation: flow,
      builder: (context, _) {
        if (flow.dailyProfiles.isEmpty) {
          return Scaffold(
            bottomNavigationBar: _BottomNavBar(
              currentIndex: 1,
              onTap: (index) {
                switch (index) {
                  case 0:
                    flow.openChatList();
                    break;
                  case 1:
                    flow.openFeed();
                    break;
                  case 2:
                    flow.openPaths();
                    break;
                  case 3:
                    flow.openBlinds();
                    break;
                  case 4:
                    flow.openProfileSettings();
                    break;
                }
              },
            ),
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [FreezmeColors.surface, FreezmeColors.surfaceAlt],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const FreezmeLogo(size: LogoSize.md, showText: true),
                        const SizedBox(height: 12),
                        const Text(
                          'You’re all caught up for today.',
                          style: FreezmeTypography.title,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Check back later or expand your radius on Paths.',
                          style: FreezmeTypography.bodyMuted,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: flow.openPaths,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(200, 48),
                            backgroundColor: FreezmeColors.primary,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Discover on Paths'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final VibeProfile profile = flow.currentProfile;
        final int remaining = flow.remainingProfiles;

        return Scaffold(
          bottomNavigationBar: _BottomNavBar(
            currentIndex: 1,
            onTap: (index) {
              switch (index) {
                case 0:
                  flow.openChatList();
                  break;
                case 1:
                  flow.openFeed();
                  break;
                case 2:
                  flow.openPaths();
                  break;
                case 3:
                  flow.openBlinds();
                  break;
                case 4:
                  flow.openProfileSettings();
                  break;
              }
            },
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [FreezmeColors.surface, FreezmeColors.surfaceAlt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const FreezmeLogo(
                              size: LogoSize.sm,
                              showText: true,
                            ),
                            const Spacer(),
                            IconButton.outlined(
                              onPressed: flow.openDailyRecap,
                              icon: const Icon(Icons.trending_up),
                              color: FreezmeColors.primary,
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              onPressed: flow.openProfileSettings,
                              icon: const Icon(Icons.settings),
                              color: FreezmeColors.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          flow.vibesRemaining <= 0
                              ? 'Last vibe — make it count 💫'
                              : 'Your ${flow.dailyProfiles.length} vibes are ready 💫',
                          style: const TextStyle(
                            color: FreezmeColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            for (var i = 0; i < flow.dailyProfiles.length; i++)
                              Expanded(
                                child: Container(
                                  height: 4,
                                  margin: EdgeInsets.only(
                                    right: i == flow.dailyProfiles.length - 1
                                        ? 0
                                        : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: i <= flow.poolIndex
                                        ? FreezmeColors.primary
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final dpr = MediaQuery.of(context).devicePixelRatio;
                          final memCacheWidth =
                              (constraints.maxWidth * dpr).round();
                          return AspectRatio(
                            aspectRatio: 3 / 4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: profile.imageUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth: memCacheWidth,
                                    placeholder: (context, url) =>
                                        const ColoredBox(
                                      color: FreezmeColors.border,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const ColoredBox(
                                      color: FreezmeColors.border,
                                      child: Icon(Icons.person, size: 48),
                                    ),
                                  ),
                                  Positioned(
                                    top: 20,
                                    right: 20,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            FreezmeColors.primary,
                                            FreezmeColors.secondary,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(999),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '${profile.compatibility}% Match',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black87,
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${profile.name}, ${profile.age}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            profile.distance,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            profile.bio,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton.outlined(
                              onPressed: flow.isSendingAction ? null : flow.passCurrent,
                              icon: const Icon(Icons.close),
                              color: FreezmeColors.muted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: FreezmeColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(56),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: flow.isSendingAction
                                    ? null
                                    : () async {
                                        try {
                                          await _handleInvite(
                                              context, flow, profile);
                                        } catch (_) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Could not send invite. Please retry.'),
                                            ),
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.favorite),
                                label: const Text('Invite to Vibe'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: flow.superVibesRemaining > 0
                                        ? FreezmeColors.secondary
                                        : FreezmeColors.muted,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(56, 44),
                                    shape: const StadiumBorder(),
                                  ),
                                  onPressed: flow.superVibesRemaining > 0 &&
                                          !flow.isSendingAction
                                      ? () => flow.likeCurrent(superLike: true)
                                      : null,
                                  icon: const Icon(Icons.auto_awesome),
                                  label: const Text('Super'),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${flow.superVibesRemaining} left',
                                  style: const TextStyle(
                                    color: FreezmeColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          remaining == 0
                              ? 'Last vibe for today'
                              : '$remaining ${remaining == 1 ? 'vibe' : 'vibes'} remaining today',
                          style: const TextStyle(
                            color: FreezmeColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: flow.openFreezmePlus,
                          child: const Text('Level up with Freezme+'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class VideoDatePage extends StatefulWidget {
  const VideoDatePage({super.key});

  @override
  State<VideoDatePage> createState() => _VideoDatePageState();
}

class _VideoDatePageState extends State<VideoDatePage>
    with SingleTickerProviderStateMixin {
  static const int _totalSeconds = 1200;

  late Timer _timer;
  int _timeRemaining = _totalSeconds;
  bool _isMuted = false;
  String? _reaction;
  Timer? _reactionTimer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timeRemaining == 0) {
        AppFlowScope.of(context, listen: false).completeVideoDate();
        timer.cancel();
      } else {
        setState(() => _timeRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _reactionTimer?.cancel();
    super.dispose();
  }

  void _handleReaction(String emoji) {
    _reactionTimer?.cancel();
    setState(() => _reaction = emoji);
    _reactionTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _reaction = null);
    });
  }

  String get _formattedTime {
    final minutes = _timeRemaining ~/ 60;
    final seconds = _timeRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final profile = flow.activeProfile;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              FreezmeColors.neutral,
              Color(0xFF3D2D4D),
              Color(0xFF4D2D3D),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                profile?.imageUrl ??
                                    'https://images.unsplash.com/photo-1546961329-78bef0414d7c?fit=crop&w=1080',
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    profile != null
                                        ? '${profile.name}, ${profile.age}'
                                        : 'Your match',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                              if (_reaction != null)
                                Center(
                                  child: AnimatedScale(
                                    scale: 1.4,
                                    duration: const Duration(milliseconds: 600),
                                    child: Text(
                                      _reaction!,
                                      style: const TextStyle(fontSize: 72),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 160,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                'https://images.unsplash.com/flagged/photo-1596479042555-9265a7fa7983?fit=crop&w=1080',
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                bottom: 16,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'You',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Time Remaining',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                _formattedTime,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: _timeRemaining / _totalSeconds,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation(
                                FreezmeColors.secondary,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final emoji in ['❤️', '😂', '🙌'])
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: GestureDetector(
                              onTap: () => _handleReaction(emoji),
                              child: Container(
                                height: 56,
                                width: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: Colors.white24),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _isMuted = !_isMuted),
                          child: Container(
                            height: 64,
                            width: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: Colors.white24),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              _isMuted ? Icons.volume_off : Icons.volume_up,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        GestureDetector(
                          onTap: () {
                            AppFlowScope.of(
                              context,
                              listen: false,
                            ).completeVideoDate();
                          },
                          child: Container(
                            height: 72,
                            width: 72,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  FreezmeColors.accent,
                                  FreezmeColors.secondary,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x33C471ED),
                                  blurRadius: 16,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Transform.rotate(
                              angle: math.pi * 0.75,
                              child: const Icon(
                                Icons.phone,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MatchSuccessPage extends StatelessWidget {
  const MatchSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    final profile = flow.activeProfile;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              FreezmeColors.primary,
              FreezmeColors.secondary,
              FreezmeColors.accent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 96),
                  const SizedBox(height: 24),
                  Text(
                    'It\'s a Vibe! 💜',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile != null
                        ? 'You and ${profile.name} both felt the connection'
                        : 'Your match is excited to chat',
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MatchAvatar(
                        imageUrl:
                            'https://images.unsplash.com/flagged/photo-1596479042555-9265a7fa7983?fit=crop&w=320',
                        label: 'You',
                      ),
                      const SizedBox(width: 24),
                      const Text('💜', style: TextStyle(fontSize: 48)),
                      const SizedBox(width: 24),
                      _MatchAvatar(
                        imageUrl:
                            profile?.imageUrl ??
                            'https://images.unsplash.com/photo-1546961329-78bef0414d7c?fit=crop&w=320',
                        label: profile?.name ?? 'Match',
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: FreezmeColors.primary,
                      minimumSize: const Size.fromHeight(56),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: flow.finishMatchSuccessToChat,
                    icon: const Icon(Icons.message_outlined),
                    label: const Text('Start Chat'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      minimumSize: const Size.fromHeight(56),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: flow.finishMatchSuccessToPool,
                    child: const Text('Maybe Later'),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Good vibes only 💫',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchAvatar extends StatelessWidget {
  const _MatchAvatar({required this.imageUrl, required this.label});

  final String imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 96,
          width: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(imageUrl, fit: BoxFit.cover),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  bool _notifications = true;
  bool _showOnline = true;
  bool _readReceipts = false;
  bool _signingOut = false;

  double _completion(AppFlowController flow) {
    final uploaded = flow.photoSlots
        .where((p) => p.status == PhotoSlotStatus.uploaded)
        .length;
    final base = 50;
    final photos = (uploaded / flow.photoSlots.length) * 40;
    final onboarding = flow.stack.contains(AppStage.onboarding) ? 0 : 10;
    return (base + photos + onboarding).clamp(0, 100);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _confirmSignOut(AppFlowController flow) async {
    if (_signingOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'We’ll pause your presence and take you back to the welcome screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _signingOut = true);
    try {
      await flow.signOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final completion = _completion(flow).round();
    final vibesLeft = flow.remainingProfiles;
    final matchesCount = flow.matches.length;
    final menuItems = [
      (
        icon: Icons.person_outline,
        label: 'Edit Profile',
        description: 'Update your photos and bio',
        action: flow.openProfilePreview,
      ),
      (
        icon: Icons.tune,
        label: 'Preferences',
        description: 'Age range, distance, interests',
        action: () {},
      ),
      (
        icon: Icons.workspace_premium_outlined,
        label: 'Freezme+',
        description: 'Manage membership and perks',
        action: flow.openFreezmePlus,
      ),
      (
        icon: Icons.shield_outlined,
        label: 'Safety & Privacy',
        description: 'Block list, data settings',
        action: () {},
      ),
      (
        icon: Icons.help_outline,
        label: 'Help & Support',
        description: 'FAQs, contact us',
        action: () {},
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [FreezmeColors.primary, FreezmeColors.secondary],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FreezmeLogo(
                      size: LogoSize.sm,
                      variant: LogoVariant.white,
                      showText: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton.filled(
                          onPressed: flow.pop,
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Profile & Settings',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 80,
                              width: 80,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    FreezmeColors.primary,
                                    FreezmeColors.secondary,
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sarah Johnson',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: FreezmeColors.neutral,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'sarah@example.com',
                                    style: TextStyle(
                                      color: FreezmeColors.muted,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: FreezmeColors.surface,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: FreezmeColors.border,
                                      ),
                                    ),
                                    child: Text(
                                      '$completion% Complete',
                                      style: const TextStyle(
                                        color: FreezmeColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _StatPill(
                            label: 'Vibes left today',
                            value: vibesLeft.toString(),
                            icon: Icons.favorite_border,
                          ),
                          const SizedBox(width: 8),
                          _StatPill(
                            label: 'Matches',
                            value: matchesCount.toString(),
                            icon: Icons.chat_bubble_outline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Quick Settings',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: FreezmeColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _SettingsToggleTile(
                              icon: Icons.notifications_outlined,
                              title: 'Notifications',
                              subtitle: 'Push & email alerts',
                              value: _notifications,
                              onChanged: (value) {
                                setState(() => _notifications = value);
                                _showSnack(
                                  value
                                      ? 'Notifications enabled'
                                      : 'Notifications muted',
                                );
                              },
                            ),
                            const Divider(height: 32),
                            _SettingsToggleTile(
                              icon: Icons.visibility_outlined,
                              title: 'Show Online Status',
                              subtitle: 'Let matches see when you\'re active',
                              value: _showOnline,
                              onChanged: (value) {
                                setState(() => _showOnline = value);
                                _showSnack(
                                  value
                                      ? 'Online status visible to matches'
                                      : 'You’re now hidden',
                                );
                              },
                            ),
                            const Divider(height: 32),
                            _SettingsToggleTile(
                              icon: Icons.favorite_outline,
                              title: 'Read Receipts',
                              subtitle: 'Show when you\'ve read messages',
                              value: _readReceipts,
                              onChanged: (value) {
                                setState(() => _readReceipts = value);
                                _showSnack(
                                  value
                                      ? 'Read receipts on'
                                      : 'Read receipts off',
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < menuItems.length; i++) ...[
                              _LinkTile(
                                icon: menuItems[i].icon,
                                title: menuItems[i].label,
                                subtitle: menuItems[i].description,
                                onTap: menuItems[i].action,
                              ),
                              if (i < menuItems.length - 1)
                                const Divider(height: 0),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: FreezmeColors.accent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: const StadiumBorder(),
                          side: const BorderSide(color: FreezmeColors.border),
                        ),
                        onPressed: _signingOut ? null : () => _confirmSignOut(flow),
                        icon: _signingOut
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.logout),
                        label: Text(_signingOut ? 'Signing out…' : 'Sign Out'),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Version 1.0.0 • Made with 💜',
                        style: TextStyle(
                          color: FreezmeColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  const _SettingsToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: FreezmeColors.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: FreezmeColors.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: FreezmeColors.neutral,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: FreezmeColors.muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: FreezmeColors.primary,
          inactiveTrackColor: FreezmeColors.border,
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return FreezmeColors.muted;
          }),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FreezmeColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: FreezmeColors.primary),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: FreezmeColors.neutral,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: FreezmeColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: FreezmeColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: FreezmeColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: FreezmeColors.neutral,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: FreezmeColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: FreezmeColors.muted),
          ],
        ),
      ),
    );
  }
}

class ProfilePreviewPage extends StatelessWidget {
  const ProfilePreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final uploadedPhotos = flow.photoSlots
        .where((p) => p.status == PhotoSlotStatus.uploaded && p.imageUrl != null)
        .map((p) => p.imageUrl!)
        .toList();
    final primaryPhoto = uploadedPhotos.isNotEmpty
        ? uploadedPhotos.first
        : 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&q=80&w=1080';
    final completion = ((uploadedPhotos.length / flow.photoSlots.length) * 100)
        .clamp(0, 100)
        .round();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: flow.pop,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FreezmeLogo(size: LogoSize.md, showText: true),
                const SizedBox(height: 20),
                Text(
                  'Your Vibe Profile',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: FreezmeColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  uploadedPhotos.isEmpty
                      ? 'Add a few photos to complete your vibe 💜'
                      : 'Looking good! $completion% complete',
                  style: const TextStyle(color: FreezmeColors.muted),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final dpr = MediaQuery.of(context).devicePixelRatio;
                          final memCacheWidth =
                              (constraints.maxWidth * dpr).round();
                          return SizedBox(
                            height: 320,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: primaryPhoto,
                                  fit: BoxFit.cover,
                                  memCacheWidth: memCacheWidth,
                                  placeholder: (context, url) =>
                                      const ColoredBox(
                                    color: FreezmeColors.border,
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const ColoredBox(
                                    color: FreezmeColors.border,
                                    child: Icon(Icons.person, size: 48),
                                  ),
                                ),
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [Colors.black54, Colors.transparent],
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  left: 24,
                                  right: 24,
                                  bottom: 24,
                                  child: Text(
                                    'Your vibe',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'About Me',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: FreezmeColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Finish your bio and preferences to help matches get to know you. You can edit photos, interests, and distance in Settings.',
                              style: TextStyle(
                                color: FreezmeColors.neutral,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (uploadedPhotos.isNotEmpty) ...[
                              Text(
                                'Photos',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: FreezmeColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: uploadedPhotos
                                    .map(
                                      (url) => ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.network(
                                          url,
                                          width: 96,
                                          height: 96,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 24),
                            ],
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      flow.startOnboarding(), // reuse uploader
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: FreezmeColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                  ),
                                  icon: const Icon(Icons.photo_camera_back),
                                  label: const Text('Edit photos'),
                                ),
                                const SizedBox(width: 12),
                                TextButton(
                                  onPressed: flow.openProfileSettings,
                                  child: const Text('Edit details'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Interests',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: FreezmeColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: const [
                                _GradientChip(label: 'Music'),
                                _GradientChip(label: 'Travel'),
                                _GradientChip(label: 'Art'),
                                _GradientChip(label: 'Yoga'),
                                _GradientChip(label: 'Coffee'),
                                _GradientChip(label: 'Photography'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: FreezmeColors.muted),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: FreezmeColors.neutral)),
      ],
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: FreezmeColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: FreezmeColors.border),
      ),
      child: Text(label, style: const TextStyle(color: FreezmeColors.primary)),
    );
  }
}

class _GradientChip extends StatelessWidget {
  const _GradientChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [FreezmeColors.secondary, FreezmeColors.accent],
        ),
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class DailyRecapPage extends StatelessWidget {
  const DailyRecapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    final matches = flow.matches;
    final newVibes = flow.dailyProfiles.length;
    final videoDates = matches.length;
    final messages = matches.length * 4;
    final profileViews = 20 + matches.length * 2;

    final stats = [
      (
        icon: Icons.favorite,
        label: 'New Vibes',
        value: '$newVibes',
        gradient: const LinearGradient(
          colors: [FreezmeColors.secondary, FreezmeColors.accent],
        ),
      ),
      (
        icon: Icons.videocam,
        label: 'Video Dates',
        value: '$videoDates',
        gradient: const LinearGradient(
          colors: [FreezmeColors.primary, FreezmeColors.secondary],
        ),
      ),
      (
        icon: Icons.message_outlined,
        label: 'Messages',
        value: '$messages',
        gradient: const LinearGradient(
          colors: [FreezmeColors.accent, FreezmeColors.success],
        ),
      ),
      (
        icon: Icons.trending_up,
        label: 'Profile Views',
        value: '$profileViews',
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5FBF), FreezmeColors.primary],
        ),
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      const FreezmeLogo(size: LogoSize.sm, showText: true),
                      const SizedBox(height: 20),
                      const Text('✨', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 12),
                      Text(
                        'Your Daily Recap',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: FreezmeColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Here\'s how your vibe journey is going',
                        style: TextStyle(color: FreezmeColors.muted),
                      ),
                      const SizedBox(height: 24),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                        itemCount: stats.length,
                        itemBuilder: (context, index) {
                          final stat = stats[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  height: 56,
                                  width: 56,
                                  decoration: BoxDecoration(
                                    gradient: stat.gradient,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Icon(
                                    stat.icon,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  stat.value,
                                  style: const TextStyle(
                                    color: FreezmeColors.neutral,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  stat.label,
                                  style: const TextStyle(
                                    color: FreezmeColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today\'s Highlights',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: FreezmeColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            const _RecapBullet(
                              color: FreezmeColors.primary,
                              text:
                                  'You had a great vibe date that turned into a chat! 💜',
                            ),
                            const SizedBox(height: 8),
                            _RecapBullet(
                              color: FreezmeColors.secondary,
                              text:
                                  '${matches.length} people viewed your profile today',
                            ),
                            const SizedBox(height: 8),
                            const _RecapBullet(
                              color: FreezmeColors.accent,
                              text:
                                  'You\'re in the top 10% most active users this week! 🎉',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              FreezmeColors.primary,
                              FreezmeColors.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: const [
                            Text('💫', style: TextStyle(fontSize: 32)),
                            SizedBox(height: 12),
                            Text(
                              'The best connections happen when you\'re your authentic self 💜',
                              style: TextStyle(
                                color: Colors.white,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: FreezmeColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => flow.returnToPool(resetIndex: true),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('See Tomorrow\'s Vibes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecapBullet extends StatelessWidget {
  const _RecapBullet({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 8,
          width: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: FreezmeColors.neutral),
          ),
        ),
      ],
    );
  }
}

class CompatibilityQuizPage extends StatefulWidget {
  const CompatibilityQuizPage({super.key});

  @override
  State<CompatibilityQuizPage> createState() => _CompatibilityQuizPageState();
}

class _CompatibilityQuizPageState extends State<CompatibilityQuizPage> {
  static const _questions = <({String emoji, String text})>[
    (emoji: '💬', text: 'I prefer deep conversations over small talk'),
    (emoji: '🎒', text: 'I enjoy spontaneous adventures'),
    (emoji: '⏰', text: 'Quality time is my love language'),
    (emoji: '🏠', text: 'I\'m more introverted than extroverted'),
    (emoji: '🤗', text: 'Physical touch is important to me'),
    (emoji: '🎯', text: 'I value ambition and drive'),
    (emoji: '🧘', text: 'I need alone time to recharge'),
    (emoji: '📅', text: 'I\'m a planner, not a go-with-the-flow person'),
    (emoji: '💖', text: 'I express my feelings openly'),
    (emoji: '🎨', text: 'Shared hobbies are essential in a relationship'),
  ];

  int _currentQuestion = 0;
  final List<double> _answers = List<double>.filled(
    _questions.length,
    50.0,
    growable: false,
  );

  void _handleNext(AppFlowController flow) {
    if (_currentQuestion < _questions.length - 1) {
      setState(() => _currentQuestion++);
    } else {
      flow.finishCompatibilityQuiz();
    }
  }

  void _handleBack() {
    if (_currentQuestion > 0) {
      setState(() => _currentQuestion--);
    }
  }

  String _emojiForValue(double value) {
    if (value < 25) return '😐';
    if (value < 50) return '🙂';
    if (value < 75) return '😊';
    return '😍';
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final progress = (_currentQuestion + 1) / _questions.length;
    final question = _questions[_currentQuestion];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FreezmeLogo(size: LogoSize.sm, showText: true),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: FreezmeColors.border,
                        valueColor: const AlwaysStoppedAnimation(
                          FreezmeColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Question ${_currentQuestion + 1} of ${_questions.length}',
                      style: const TextStyle(color: FreezmeColors.muted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          question.emoji,
                          style: const TextStyle(fontSize: 60),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          question.text,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: FreezmeColors.neutral,
                                fontWeight: FontWeight.w600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          _emojiForValue(_answers[_currentQuestion]),
                          style: const TextStyle(fontSize: 60),
                        ),
                        const SizedBox(height: 16),
                        Slider(
                          value: _answers[_currentQuestion],
                          onChanged: (value) {
                            setState(() {
                              _answers[_currentQuestion] = value;
                            });
                          },
                          min: 0,
                          max: 100,
                          activeColor: FreezmeColors.primary,
                          inactiveColor: FreezmeColors.border,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                'Disagree',
                                style: TextStyle(color: FreezmeColors.muted),
                              ),
                              Text(
                                'Agree',
                                style: TextStyle(color: FreezmeColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: _currentQuestion == 0 ? null : _handleBack,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FreezmeColors.primary,
                        side: const BorderSide(color: FreezmeColors.border),
                        shape: const StadiumBorder(),
                        minimumSize: const Size(56, 56),
                      ),
                      child: const Icon(Icons.chevron_left),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: FreezmeColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => _handleNext(flow),
                        icon: Icon(
                          _currentQuestion == _questions.length - 1
                              ? Icons.check
                              : Icons.chevron_right,
                        ),
                        label: Text(
                          _currentQuestion == _questions.length - 1
                              ? 'Complete'
                              : 'Next',
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
}

class ChatScreenPage extends StatefulWidget {
  const ChatScreenPage({super.key});

  @override
  State<ChatScreenPage> createState() => _ChatScreenPageState();
}

enum _MessageStatus { pending, sent, delivered, read, failed }

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.status = _MessageStatus.sent,
  });

  final String text;
  final bool isMe;
  final String timestamp;
  _MessageStatus status;
}

IconData _statusIcon(_MessageStatus status) {
  switch (status) {
    case _MessageStatus.pending:
      return Icons.access_time;
    case _MessageStatus.sent:
      return Icons.check;
    case _MessageStatus.delivered:
      return Icons.done_all;
    case _MessageStatus.read:
      return Icons.done_all;
    case _MessageStatus.failed:
      return Icons.error_outline;
  }
}

class _ChatScreenPageState extends State<ChatScreenPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  StreamSubscription<List<ChatMessage>>? _msgSub;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _msgSub?.cancel();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    final chatId = AppFlowScope.of(context, listen: false).activeChatId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (text.isEmpty || chatId == null || uid == null || _sending) return;
    _sending = true;
    final now = TimeOfDay.now();
    final message = _ChatMessage(
      text: text,
      isMe: true,
      timestamp:
          '${now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}',
      status: _MessageStatus.pending,
    );
    setState(() {
      _messages.add(message);
    });
    _controller.clear();
    try {
      final flow = AppFlowScope.of(context, listen: false);
      await flow._repository.sendMessage(
        ChatMessage(
          chatId: chatId,
          senderId: uid,
          text: text,
          sentAt: DateTime.now(),
          status: 'sent',
        ),
      );
      setState(() {
        message.status = _MessageStatus.sent;
      });
    } catch (_) {
      setState(() {
        message.status = _MessageStatus.failed;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send. Please retry.'),
        ),
      );
    } finally {
      _sending = false;
    }
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    final profile = flow.activeProfile;
    final chatId = flow.activeChatId;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [FreezmeColors.primary, FreezmeColors.secondary],
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: flow.exitChat,
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(
                        profile?.imageUrl ??
                            'https://images.unsplash.com/photo-1546961329-78bef0414d7c?fit=crop&w=320',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.name ?? 'Match',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Online',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => showFreezeModal(context),
                      icon: const Icon(Icons.ac_unit, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: chatId == null
                    ? const Center(
                        child: Text(
                          'No chat selected.',
                          style: FreezmeTypography.bodyMuted,
                        ),
                      )
                    : StreamBuilder<List<ChatMessage>>(
                        stream: flow._repository.messagesForChat(chatId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text('Could not load messages'),
                            );
                          }
                          final msgs = snapshot.data ?? const [];
                          final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                          final mapped = msgs
                              .map(
                                (m) => _ChatMessage(
                                  text: m.text,
                                  isMe: m.senderId == uid,
                                  timestamp:
                                      DateFormat('h:mm a').format(m.sentAt),
                                  status: switch (m.status) {
                                    'read' => _MessageStatus.read,
                                    'delivered' => _MessageStatus.delivered,
                                    'sent' => _MessageStatus.sent,
                                    _ => _MessageStatus.delivered,
                                  },
                                ),
                              )
                              .toList();
                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 24,
                            ),
                            itemCount: mapped.length,
                            itemBuilder: (context, index) {
                              final msg = mapped[index];
                              final bool isMe = msg.isMe;
                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.7,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isMe
                                        ? const LinearGradient(
                                            colors: [
                                              FreezmeColors.primary,
                                              FreezmeColors.secondary,
                                            ],
                                          )
                                        : null,
                                    color: isMe ? null : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(24),
                                      topRight: isMe
                                          ? const Radius.circular(8)
                                          : const Radius.circular(24),
                                      bottomLeft: isMe
                                          ? const Radius.circular(24)
                                          : const Radius.circular(8),
                                      bottomRight: const Radius.circular(24),
                                    ),
                                    boxShadow: isMe
                                        ? null
                                        : [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg.text,
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white
                                              : FreezmeColors.neutral,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            msg.timestamp,
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white70
                                                  : FreezmeColors.muted,
                                              fontSize: 11,
                                            ),
                                          ),
                                          if (isMe) ...[
                                            const SizedBox(width: 6),
                                            Icon(
                                              _statusIcon(msg.status),
                                              size: 14,
                                              color: Colors.white70,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.emoji_emotions_outlined,
                        color: FreezmeColors.primary,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _handleSend(),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          filled: true,
                          fillColor: FreezmeColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.mic_none,
                        color: FreezmeColors.primary,
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _handleSend,
                      style: IconButton.styleFrom(
                        backgroundColor: FreezmeColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.send),
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

}

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _Conversation {
  _Conversation({
    required this.chatId,
    required this.displayName,
    required this.photoUrl,
    required this.lastMessage,
    required this.timeLabel,
    this.unread = 0,
    this.status = _MessageStatus.delivered,
    this.isGroup = false,
  });

  final String chatId;
  final String displayName;
  final String photoUrl;
  String lastMessage;
  String timeLabel;
  int unread;
  _MessageStatus status;
  bool isGroup;
}

class _ChatListPageState extends State<ChatListPage> {
  List<_Conversation> _conversations = const [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_Conversation> get _visibleConversations {
    return _conversations.where((c) {
      final matchesQuery = _query.isEmpty ||
          c.displayName.toLowerCase().contains(_query.toLowerCase()) ||
          c.lastMessage.toLowerCase().contains(_query.toLowerCase());
      final matchesUnread = !_showUnreadOnly || c.unread > 0;
      return matchesQuery && matchesUnread;
    }).toList();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final flow = AppFlowScope.of(context, listen: false);
      final matches = await flow._repository.fetchMatches();
      final mapped = matches.map((m) {
        final id = m['id']?.toString() ?? '';
        final displayName = m['name']?.toString() ??
            (m['otherUserName']?.toString() ?? 'Freezme Match');
        final photo = m['photoUrl']?.toString() ?? '';
        final lastMsg = m['lastMessage']?.toString() ?? 'Tap to open chat';
        final tsString = m['updatedAt']?.toString() ??
            m['ts']?.toString() ??
            DateTime.now().toIso8601String();
        String timeLabel;
        try {
          final parsed = DateTime.tryParse(tsString);
          if (parsed != null) {
            final now = DateTime.now();
            if (now.difference(parsed).inDays >= 1) {
              timeLabel =
                  '${parsed.month}/${parsed.day}'; // simple date fallback
            } else {
              final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
              final minute = parsed.minute.toString().padLeft(2, '0');
              final ampm = parsed.hour >= 12 ? 'PM' : 'AM';
              timeLabel = '$hour:$minute $ampm';
            }
          } else {
            timeLabel = tsString;
          }
        } catch (_) {
          timeLabel = tsString;
        }
        final unread = (m['unread'] as num?)?.toInt() ?? 0;
        final statusString = m['status']?.toString();
        final status = switch (statusString) {
          'read' => _MessageStatus.read,
          'sent' => _MessageStatus.sent,
          _ => _MessageStatus.delivered,
        };
        return _Conversation(
          chatId: id,
          displayName: displayName,
          photoUrl: photo,
          lastMessage: lastMsg,
          timeLabel: timeLabel,
          unread: unread,
          status: status,
          isGroup: (m['isGroup'] as bool?) ?? false,
        );
      }).toList();
      setState(() {
        _conversations = mapped;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Could not load chats';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: true);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        FreezmeLogo(size: LogoSize.sm, showText: true),
                        Spacer(),
                        Text('Chats', style: FreezmeTypography.title),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Search chats or messages',
                        prefixIcon:
                            const Icon(Icons.search, color: FreezmeColors.muted),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: FreezmeColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: FreezmeColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: FreezmeColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilterChip(
                          selected: !_showUnreadOnly,
                          onSelected: (_) => setState(() => _showUnreadOnly = false),
                          label: const Text('All'),
                          selectedColor:
                              FreezmeColors.primary.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: !_showUnreadOnly
                                ? FreezmeColors.primary
                                : FreezmeColors.neutral,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _showUnreadOnly,
                          onSelected: (_) => setState(() => _showUnreadOnly = true),
                          label: const Text('Unread'),
                          selectedColor:
                              FreezmeColors.primary.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: _showUnreadOnly
                                ? FreezmeColors.primary
                                : FreezmeColors.neutral,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: const [
                            Icon(Icons.done_all,
                                size: 16, color: FreezmeColors.muted),
                            SizedBox(width: 4),
                            Text('Read', style: FreezmeTypography.bodyMuted),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, style: FreezmeTypography.bodyMuted),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: _loadConversations,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _visibleConversations.isEmpty
                            ? const Center(
                                child: Text(
                                  'No conversations yet.\nInvite a vibe to start chatting.',
                                  textAlign: TextAlign.center,
                                  style: FreezmeTypography.bodyMuted,
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                itemBuilder: (context, index) {
                                  final convo = _visibleConversations[index];
                                  return ListTile(
                                    onTap: () {
                                      setState(() {
                                        convo.unread = 0;
                                        convo.status = _MessageStatus.read;
                                      });
                                      flow.openChatDetail(
                                        VibeProfile(
                                          uid: convo.chatId,
                                          id: 0,
                                          name: convo.displayName,
                                          age: 0,
                                          imageUrl: convo.photoUrl,
                                          compatibility: 0,
                                          bio: '',
                                          distance: '',
                                        ),
                                        chatId: convo.chatId,
                                      );
                                    },
                                    leading: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        CircleAvatar(
                                          backgroundImage: convo.photoUrl.isNotEmpty
                                              ? CachedNetworkImageProvider(
                                                  convo.photoUrl,
                                                )
                                              : null,
                                          radius: 26,
                                          child: convo.photoUrl.isEmpty
                                              ? const Icon(Icons.person)
                                              : null,
                                        ),
                                        if (convo.unread > 0)
                                          Positioned(
                                            right: -2,
                                            top: -2,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(
                                                color: Colors.redAccent,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '${convo.unread}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    title: Text(
                                      convo.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: FreezmeColors.neutral,
                                      ),
                                    ),
                                    subtitle: Text(
                                      convo.lastMessage,
                                      style: FreezmeTypography.bodyMuted,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          convo.timeLabel,
                                          style: const TextStyle(
                                            color: FreezmeColors.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Icon(
                                          _statusIcon(convo.status),
                                          size: 14,
                                          color: FreezmeColors.muted,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  color: FreezmeColors.border,
                                ),
                                itemCount: _visibleConversations.length,
                              ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              break;
            case 1:
              flow.openFeed();
              break;
            case 2:
              flow.openPaths();
              break;
            case 3:
              flow.openBlinds();
              break;
            case 4:
              flow.openProfileSettings();
              break;
          }
        },
      ),
    );
  }
}

class PathsPage extends StatefulWidget {
  const PathsPage({super.key});

  @override
  State<PathsPage> createState() => _PathsPageState();
}

class _PathsPageState extends State<PathsPage> {
  bool visible = true;
  double radius = 10;
  final Set<String> intents = {'Friends', 'Dates'};
  bool todayOnly = true;
  int wavesLeft = 5;
  bool notifyWhenNearby = true;
  final Map<String, String> inviteStatusByUser = {};
  final Map<String, StreamSubscription<PathsInvite>> _inviteSubs = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flow = AppFlowScope.of(context, listen: false);
      _refresh(flow);
    });
  }

  @override
  void dispose() {
    for (final sub in _inviteSubs.values) {
      sub.cancel();
    }
    _inviteSubs.clear();
    super.dispose();
  }

  void _openChat(AppFlowController flow) {
    final targetProfile = flow.activeProfile ??
        (flow.matches.isNotEmpty
            ? flow.matches.first.profile
            : flow.dailyProfiles.isNotEmpty
                ? flow.dailyProfiles.first
                : null);
    if (targetProfile != null) {
      flow.openChatDetail(targetProfile);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No one nearby right now. Try again soon.'),
        ),
      );
    }
  }

  void _useWave(BuildContext context) {
    if (wavesLeft <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily waves used up. Check back tomorrow.'),
        ),
      );
      return;
    }
    setState(() => wavesLeft -= 1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Wave sent. $wavesLeft left today.'),
      ),
    );
  }

  Future<void> _refresh(AppFlowController flow) async {
    await flow.refreshPaths(radiusKm: radius, intents: intents);
    setState(() {});
  }

  Future<void> _sendInvite(
    AppFlowController flow,
    PathsPresence person,
  ) async {
    final current = inviteStatusByUser[person.userId];
    if (current == 'pending') return;
    if (wavesLeft <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Out of invites for today.')),
      );
      return;
    }
    setState(() {
      inviteStatusByUser[person.userId] = 'pending';
      wavesLeft = (wavesLeft - 1).clamp(0, 99);
    });
    try {
      final inviteId = await flow.sendPathsInvite(
        receiverUid: person.userId,
        intent: person.intents.isNotEmpty ? person.intents.first : 'Either',
      );
      if (inviteId.isEmpty) {
        throw Exception('Failed to send invite');
      }
      _inviteSubs[person.userId]?.cancel();
      _inviteSubs[person.userId] = flow.inviteStatus(inviteId).listen((invite) {
        if (!mounted) return;
        setState(() {
          inviteStatusByUser[person.userId] = invite.status;
        });
        if (invite.status == 'accepted') {
          _openChat(flow);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        inviteStatusByUser[person.userId] = 'error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send invite. Please retry.')),
      );
    }
  }

  Widget _emptyNearby() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'No one nearby yet.',
          style: TextStyle(
            color: FreezmeColors.neutral,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Try expanding your radius or check back in a bit.',
          style: FreezmeTypography.bodyMuted,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton(
              onPressed: () => setState(() => radius = (radius + 5).clamp(1, 50)),
              style: ElevatedButton.styleFrom(
                backgroundColor: FreezmeColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const Text('Expand radius +5 km'),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => setState(() => todayOnly = false),
              child: const Text('Keep me visible longer'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: notifyWhenNearby,
          onChanged: (v) => setState(() => notifyWhenNearby = v),
          title: const Text('Notify me when someone is nearby'),
          subtitle: const Text(
            'We’ll send a gentle alert once we find a good match.',
            style: FreezmeTypography.bodyMuted,
          ),
        ),
      ],
    );
  }

  String _inviteLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Pending…';
      case 'accepted':
        return 'Open chat';
      case 'declined':
        return 'Retry';
      case 'error':
        return 'Retry';
      default:
        return 'Invite';
    }
  }

  Color _buttonColor(String? status) {
    switch (status) {
      case 'pending':
        return FreezmeColors.muted;
      case 'accepted':
        return FreezmeColors.success;
      case 'declined':
      case 'error':
        return FreezmeColors.accent;
      default:
        return FreezmeColors.primary;
    }
  }

  static String _timeAgo(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          FreezmeLogo(size: LogoSize.sm, showText: true),
                          Spacer(),
                          Text('Paths', style: FreezmeTypography.title),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _surfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Visibility', style: FreezmeTypography.title),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: visible,
                              thumbColor:
                                  WidgetStateProperty.all(FreezmeColors.primary),
                              trackColor: WidgetStateProperty.all(
                                FreezmeColors.primary.withValues(alpha: 0.15),
                              ),
                              onChanged: (v) {
                                setState(() => visible = v);
                                if (v) _refresh(flow);
                              },
                              title: const Text(
                                'Show me on Paths',
                                style: TextStyle(color: FreezmeColors.neutral),
                              ),
                              subtitle: const Text(
                                'Opt in to be discoverable nearby.',
                                style: FreezmeTypography.bodyMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Distance: ${radius.round()} km',
                              style: const TextStyle(color: FreezmeColors.neutral),
                            ),
                            Slider(
                              value: radius,
                              min: 1,
                              max: 50,
                              divisions: 49,
                              activeColor: FreezmeColors.primary,
                              onChanged: (v) => setState(() => radius = v),
                              onChangeEnd: (_) => _refresh(flow),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: todayOnly,
                              onChanged: (v) => setState(() => todayOnly = v ?? true),
                              title: const Text(
                                'Visible today only',
                                style: TextStyle(color: FreezmeColors.neutral),
                              ),
                              subtitle: const Text(
                                'Auto-disables in 24h to keep you private.',
                                style: FreezmeTypography.bodyMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Chip(
                                  label: Text(
                                    '$wavesLeft waves left today',
                                    style: const TextStyle(
                                      color: FreezmeColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  backgroundColor: FreezmeColors.primary
                                      .withValues(alpha: 0.12),
                                ),
                                const Spacer(),
                                if (notifyWhenNearby)
                                  const Icon(Icons.notifications_active,
                                      size: 16, color: FreezmeColors.primary),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: ['Friends', 'Dates', 'Either'].map((label) {
                                final selected = intents.contains(label);
                                return ChoiceChip(
                                  label: Text(label),
                                  selected: selected,
                                  selectedColor:
                                      FreezmeColors.primary.withValues(alpha: 0.12),
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? FreezmeColors.primary
                                        : FreezmeColors.neutral,
                                  ),
                                  onSelected: (_) {
                                    setState(() {
                                      if (selected) {
                                        intents.remove(label);
                                      } else {
                                        intents.add(label);
                                      }
                                    });
                                    _refresh(flow);
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Nearby', style: FreezmeTypography.title),
                      const SizedBox(height: 8),
                      if (!visible)
                        const Text(
                          'Turn on visibility to see people nearby.',
                          style: FreezmeTypography.bodyMuted,
                        )
                      else if (flow.pathsLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (flow.pathsError != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              flow.pathsError!,
                              style: const TextStyle(
                                color: FreezmeColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => _refresh(flow),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        )
                      else if (flow.nearbyPaths.isEmpty)
                        _emptyNearby()
                      else
                        Column(
                          children: [
                            for (final person in flow.nearbyPaths) ...[
                              _surfaceCard(
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        width: 72,
                                        height: 72,
                                        color: FreezmeColors.surfaceAlt,
                                        child: const Icon(
                                          Icons.person,
                                          color: FreezmeColors.primary,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            person.userId,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: FreezmeColors.neutral,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (person.lastActiveAt != null)
                                            Text(
                                              'Active ${_timeAgo(person.lastActiveAt!)}',
                                              style: const TextStyle(
                                                color: FreezmeColors.primary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          if (person.availability != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                person.availability!,
                                                style: FreezmeTypography.bodyMuted,
                                              ),
                                            ),
                                          if (person.interestsSummary != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                person.interestsSummary!,
                                                style: FreezmeTypography.bodyMuted,
                                              ),
                                            ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              for (final intent in person.intents)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: FreezmeColors.primary
                                                        .withValues(alpha: 0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    intent,
                                                    style: const TextStyle(
                                                      color: FreezmeColors.primary,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              TextButton(
                                                onPressed: () {
                                                  _useWave(context);
                                                  _openChat(flow);
                                                },
                                                child: const Text('Wave'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: _buttonColor(
                                                    inviteStatusByUser[person.userId],
                                                  ),
                                                  foregroundColor: Colors.white,
                                                  minimumSize: const Size(110, 44),
                                                  shape: const StadiumBorder(),
                                                ),
                                                onPressed: () {
                                                  final status =
                                                      inviteStatusByUser[person.userId];
                                                  if (status == 'accepted') {
                                                    _openChat(flow);
                                                  } else {
                                                    _sendInvite(flow, person);
                                                  }
                                                },
                                                child: Text(
                                                  _inviteLabel(
                                                    inviteStatusByUser[person.userId],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          switch (index) {
            case 0:
              flow.openChatList();
              break;
            case 1:
              flow.openFeed();
              break;
            case 2:
              break;
            case 3:
              flow.openBlinds();
              break;
            case 4:
              flow.openProfileSettings();
              break;
          }
        },
      ),
    );
  }
}

class BlindsPage extends StatefulWidget {
  const BlindsPage({super.key});

  @override
  State<BlindsPage> createState() => _BlindsPageState();
}

class _BlindsPageState extends State<BlindsPage> with TickerProviderStateMixin {
  bool consented = false;
  bool revealAllowed = false;
  bool isSearching = false;
  double sessionProgress = 1.0;
  final List<(String, IconData)> prompts = const [
    ('What made you smile today?', Icons.sentiment_satisfied_alt),
    ('Share a small win from this week.', Icons.celebration),
    ('Describe your ideal slow Sunday.', Icons.weekend),
  ];

  late AnimationController _diceController;
  late AnimationController _cardController;

  @override
  void initState() {
    super.initState();
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _diceController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                Row(
                  children: const [
                    FreezmeLogo(size: LogoSize.sm, showText: true),
                    Spacer(),
                    Text('Blinds', style: FreezmeTypography.title),
                  ],
                ),
                const SizedBox(height: 12),
                _surfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ground rules', style: FreezmeTypography.title),
                      const SizedBox(height: 8),
                      const Text(
                        'No sharing contacts, be kind, timed chats auto-end. You can report or block anytime.',
                        style: FreezmeTypography.bodyMuted,
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: consented,
                        activeColor: FreezmeColors.primary,
                        onChanged: (v) => setState(() => consented = v ?? false),
                        title: const Text('I agree to chat respectfully'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: revealAllowed,
                        thumbColor:
                            WidgetStateProperty.all(FreezmeColors.primary),
                        trackColor: WidgetStateProperty.all(
                          FreezmeColors.primary.withValues(alpha: 0.15),
                        ),
                        onChanged: (v) => setState(() => revealAllowed = v),
                        title: const Text('Allow reveal after mutual thumbs up'),
                        subtitle: const Text(
                          'We only show photos/profile after both agree.',
                          style: FreezmeTypography.bodyMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isSearching) ...[
                        const LinearProgressIndicator(
                          minHeight: 6,
                          color: FreezmeColors.primary,
                          backgroundColor: FreezmeColors.border,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Finding someone ready to chat…',
                          style: FreezmeTypography.bodyMuted,
                        ),
                        const SizedBox(height: 12),
                      ],
                      AnimatedBuilder(
                        animation: _diceController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _diceController.value * 6.28, // Full rotation
                            child: child,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: consented
                                ? const LinearGradient(
                                    colors: [
                                      FreezmeColors.primary,
                                      FreezmeColors.secondary,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: consented ? null : FreezmeColors.muted,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: consented
                                ? [
                                    BoxShadow(
                                      color: FreezmeColors.primary.withValues(alpha: 0.4),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                    ),
                                  ]
                                : null,
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              minimumSize: const Size.fromHeight(56),
                            ),
                            onPressed: consented
                                ? () {
                                    _diceController.forward(from: 0);
                                    setState(() => isSearching = true);
                                    final messenger = ScaffoldMessenger.of(context);
                                    Future<void>.delayed(
                                      const Duration(seconds: 1),
                                      () {
                                        if (!mounted) return;
                                        final targetProfile = flow.activeProfile ??
                                            (flow.matches.isNotEmpty
                                                ? flow.matches.first.profile
                                                : flow.dailyProfiles.isNotEmpty
                                                    ? flow.dailyProfiles.first
                                                    : null);
                                        if (targetProfile != null) {
                                          flow.openChatDetail(targetProfile);
                                        } else {
                                          if (!mounted) return;
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'No partners available right now. We\'ll keep you in queue.',
                                              ),
                                              backgroundColor: FreezmeColors.primary,
                                            ),
                                          );
                                        }
                                        if (!mounted) return;
                                        setState(() => isSearching = false);
                                      },
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.casino, size: 24),
                            label: const Text(
                              'Roll the dice',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (consented) ...[
                  _surfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current session', style: FreezmeTypography.title),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: sessionProgress,
                          minHeight: 8,
                          color: FreezmeColors.primary,
                          backgroundColor: FreezmeColors.border,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Blind chats auto-end to keep it fresh. Mutual thumbs up can extend and reveal.',
                          style: FreezmeTypography.bodyMuted,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FreezmeColors.primary,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () {
                                if (sessionProgress > 0.2) {
                                  setState(() {
                                    sessionProgress -= 0.2;
                                  });
                                }
                              },
                              child: const Text('Thumbs up'),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() => sessionProgress = 0);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Session ended. Roll again when ready.'),
                                  ),
                                );
                              },
                              child: const Text('End & roll again'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Icebreakers', style: FreezmeTypography.title),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: prompts
                      .map(
                        (p) => InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied: "${p.$1}"'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: FreezmeColors.border,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: FreezmeColors.primary.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  p.$2,
                                  size: 18,
                                  color: FreezmeColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    p.$1,
                                    style: const TextStyle(
                                      color: FreezmeColors.neutral,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.report_gmailerrorred,
                      color: FreezmeColors.accent),
                  label: const Text(
                    'How we keep Blinds safe',
                    style: TextStyle(color: FreezmeColors.accent),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        currentIndex: 3,
        onTap: (index) {
          switch (index) {
            case 0:
              flow.openChatList();
              break;
            case 1:
              flow.openFeed();
              break;
            case 2:
              flow.openPaths();
              break;
            case 3:
              break;
            case 4:
              flow.openProfileSettings();
              break;
          }
        },
      ),
    );
  }
}

class FreezeMePlusPage extends StatelessWidget {
  const FreezeMePlusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    final features = [
      (
        icon: Icons.access_time,
        title: 'Extend Freeze',
        description:
            'Pause your profile for up to 7 days without losing matches',
        gradient: const LinearGradient(
          colors: [FreezmeColors.primary, FreezmeColors.secondary],
        ),
      ),
      (
        icon: Icons.favorite,
        title: 'Extra Vibes',
        description: 'Get 6 daily matches instead of 3 for more connections',
        gradient: const LinearGradient(
          colors: [FreezmeColors.secondary, FreezmeColors.accent],
        ),
      ),
      (
        icon: Icons.public,
        title: 'Global Visibility',
        description: 'Connect with people beyond your local area',
        gradient: const LinearGradient(
          colors: [FreezmeColors.accent, FreezmeColors.success],
        ),
      ),
      (
        icon: Icons.auto_awesome,
        title: 'Priority Match',
        description: 'Your profile gets shown first to your top matches',
        gradient: const LinearGradient(
          colors: [FreezmeColors.primary, Color(0xFF8B5FBF)],
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: flow.pop,
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const FreezmeLogo(size: LogoSize.sm, showText: true),
                const SizedBox(height: 24),
                const Text('✨', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 12),
                Text(
                  'Level up your vibe',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: FreezmeColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Get premium features to enhance your dating experience',
                  style: TextStyle(color: FreezmeColors.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                for (final feature in features) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: FreezmeColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 56,
                          width: 56,
                          decoration: BoxDecoration(
                            gradient: feature.gradient,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            feature.icon,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feature.title,
                                style: const TextStyle(
                                  color: FreezmeColors.neutral,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                feature.description,
                                style: const TextStyle(
                                  color: FreezmeColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check, color: FreezmeColors.primary),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [FreezmeColors.primary, FreezmeColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Monthly Subscription',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Text(
                            '₹499',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            '/month',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Cancel anytime • No commitment',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: FreezmeColors.primary,
                          minimumSize: const Size.fromHeight(56),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () {},
                        child: const Text('Unlock Freezme+ ✨'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Join 10,000+ premium members finding meaningful connections',
                  style: TextStyle(color: FreezmeColors.muted),
                  textAlign: TextAlign.center,
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Terms & Conditions'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
        label: 'Compatibility Quiz',
        action: () => flow.replaceStack(<AppStage>[
          AppStage.onboarding,
          AppStage.compatibilityQuiz,
        ]),
      ),
      (
        label: 'Daily Vibe Pool',
        action: () => flow.replaceStack(<AppStage>[AppStage.dailyPool]),
      ),
      (
        label: 'Video Date',
        action: () {
          flow.replaceStack(<AppStage>[AppStage.dailyPool]);
          flow.startVideoDate(flow.currentProfile);
        },
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

enum LogoSize { sm, md, lg }

enum LogoVariant { primary, white, gradient }

class FreezmeLogo extends StatelessWidget {
  const FreezmeLogo({
    super.key,
    this.size = LogoSize.md,
    this.variant = LogoVariant.primary,
    this.showText = false,
  });

  final LogoSize size;
  final LogoVariant variant;
  final bool showText;

  static const _sizeMap = {
    LogoSize.sm: (heart: 32.0, snowflake: 16.0, text: 14.0),
    LogoSize.md: (heart: 48.0, snowflake: 24.0, text: 18.0),
    LogoSize.lg: (heart: 72.0, snowflake: 36.0, text: 22.0),
  };

  static final _colorMap = {
    LogoVariant.primary: (
      heart: FreezmeColors.primary,
      snowflake: Colors.white,
      text: FreezmeColors.primary,
    ),
    LogoVariant.white: (
      heart: Colors.white,
      snowflake: FreezmeColors.primary,
      text: Colors.white,
    ),
    LogoVariant.gradient: (
      heart: FreezmeColors.primary,
      snowflake: Colors.white,
      text: FreezmeColors.primary,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final metrics = _sizeMap[size]!;
    final colors = _colorMap[variant]!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: metrics.heart,
          height: metrics.heart,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (variant == LogoVariant.gradient)
                ShaderMask(
                  shaderCallback: (rect) =>
                      FreezmeGradients.primary.createShader(rect),
                  blendMode: BlendMode.srcIn,
                  child: Icon(
                    Icons.favorite,
                    size: metrics.heart,
                    color: Colors.white,
                  ),
                )
              else
                Icon(Icons.favorite, size: metrics.heart, color: colors.heart),
              Icon(
                Icons.ac_unit,
                size: metrics.snowflake,
                color: colors.snowflake,
              ),
            ],
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          Text(
            'FREEZME',
            style: TextStyle(
              color: colors.text,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              fontSize: metrics.text,
            ),
          ),
        ],
      ],
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
