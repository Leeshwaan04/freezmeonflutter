import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/melt_chat_service.dart';
import 'services/photo_upload_service.dart';

import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FreezmeApp());
}

enum AppStage {
  splash,
  authGate,
  onboarding,
  compatibilityQuiz,
  dailyPool,
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
  }) : _photoUploadService = photoUploadService ?? MockPhotoUploadService(),
       _meltChatService = meltChatService ?? MockMeltChatService(),
       photoSlots = List<PhotoSlot>.generate(6, (_) => const PhotoSlot()),
       dailyProfiles = _mockProfiles() {
    _hydrate();
  }

  static Future<AppFlowController> create({
    PhotoUploadService? photoUploadService,
    MeltChatService? meltChatService,
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
    );
  }

  static AppFlowController test({
    SharedPreferences? prefs,
    PhotoUploadService? photoUploadService,
    MeltChatService? meltChatService,
  }) {
    return AppFlowController._(
      prefs,
      photoUploadService: photoUploadService,
      meltChatService: meltChatService,
    );
  }

  final SharedPreferences? _prefs;
  final PhotoUploadService _photoUploadService;
  final MeltChatService _meltChatService;
  final List<AppStage> _stack = <AppStage>[AppStage.splash];
  final List<AppMatch> matches = <AppMatch>[];
  final List<VibeProfile> dailyProfiles;
  final List<PhotoSlot> photoSlots;
  VibeProfile? activeProfile;
  String? _pendingInviteSlot;
  int _poolIndex = 0;

  List<AppStage> get stack => List.unmodifiable(_stack);
  AppStage get current => _stack.last;
  int get poolIndex => _poolIndex;
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

  Future<void> signOut() async {
    activeProfile = null;
    _pendingInviteSlot = null;
    _poolIndex = 0;
    matches.clear();
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
                            child: const SizedBox(
                              height: 120,
                              width: 120,
                              child: Center(
                                child: FreezmeLogo(size: LogoSize.lg),
                              ),
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

class AuthGatePage extends StatelessWidget {
  const AuthGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FreezmeInsets.pageGutter,
                    vertical: FreezmeInsets.sectionSpacing,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: FreezmeInsets.elementSpacing * 1.5,
                            vertical: FreezmeInsets.sectionSpacing * 1.4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              FreezmeInsets.cardRadius,
                            ),
                          ),
                          child: Column(
                            children: [
                              const FreezmeLogo(
                                size: LogoSize.lg,
                                variant: LogoVariant.primary,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          height: FreezmeInsets.sectionSpacing * 1.2,
                        ),
                        _AuthButton(
                          label: 'Continue with Apple',
                          icon: Icons.apple,
                          gradient: FreezmeGradients.primary,
                          foreground: Colors.white,
                          onTap: flow.startOnboarding,
                        ),
                        const SizedBox(height: FreezmeInsets.elementSpacing),
                        _AuthButton(
                          label: 'Continue with Google',
                          icon: Icons.g_mobiledata,
                          foreground: FreezmeColors.primary,
                          background: Colors.white,
                          border: const BorderSide(
                            color: FreezmeColors.primary,
                            width: 2,
                          ),
                          onTap: flow.startOnboarding,
                        ),
                        const SizedBox(height: FreezmeInsets.elementSpacing),
                        _AuthButton(
                          label: 'Continue with Email',
                          icon: Icons.mail_outline,
                          gradient: FreezmeGradients.primary,
                          foreground: Colors.white,
                          onTap: flow.startOnboarding,
                        ),
                        const SizedBox(height: FreezmeInsets.sectionSpacing),
                        const Text(
                          'Your vibe begins with one tap 💫',
                          style: FreezmeTypography.bodyMuted,
                        ),
                        const SizedBox(height: FreezmeInsets.elementSpacing),
                        Text.rich(
                          TextSpan(
                            text: 'By continuing you agree to our ',
                            style: FreezmeTypography.bodyMuted.copyWith(
                              fontSize: 13,
                            ),
                            children: const [
                              TextSpan(
                                text: 'Terms',
                                style: TextStyle(
                                  color: FreezmeColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: FreezmeColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              TextSpan(text: '.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
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
            ],
          ),
        ),
      ),
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
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? background;
  final Color? foreground;
  final Gradient? gradient;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final textColor = foreground ?? Colors.white;
    final borderSide = border;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? background : null,
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
              Icon(icon, color: textColor),
              const SizedBox(width: 12),
              Text(
                label,
                style: FreezmeTypography.button.copyWith(color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    flow.beginCompatibilityQuiz();
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
              const Text(
                'Bio',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: FreezmeColors.neutral,
                ),
              ),
              const SizedBox(height: FreezmeInsets.elementSpacing / 2),
              TextField(
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'What makes you, you?',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      FreezmeInsets.cardRadius,
                    ),
                    borderSide: const BorderSide(color: FreezmeColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      FreezmeInsets.cardRadius,
                    ),
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
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '25',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                FreezmeInsets.cardRadius,
                              ),
                              borderSide: const BorderSide(
                                color: FreezmeColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                FreezmeInsets.cardRadius,
                              ),
                              borderSide: const BorderSide(
                                color: FreezmeColors.border,
                              ),
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
                              borderSide: const BorderSide(
                                color: FreezmeColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                FreezmeInsets.cardRadius,
                              ),
                              borderSide: const BorderSide(
                                color: FreezmeColors.border,
                              ),
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
                children: const [
                  _InterestChip(label: 'Music'),
                  _InterestChip(label: 'Travel'),
                  _InterestChip(label: 'Art'),
                  _InterestChip(label: 'Fitness'),
                  _InterestChip(label: 'Food'),
                  _InterestChip(label: 'Books'),
                ],
              ),
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

class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: Colors.white,
      shape: const StadiumBorder(),
      labelStyle: FreezmeTypography.body.copyWith(
        fontWeight: FontWeight.w500,
        color: FreezmeColors.neutral,
      ),
      side: const BorderSide(color: FreezmeColors.border),
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
        final VibeProfile profile = flow.currentProfile;
        final int remaining = flow.remainingProfiles;

        return Scaffold(
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
                          'Your ${flow.dailyProfiles.length} vibes are ready 💫',
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
                            Image.network(
                              profile.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              onPressed: flow.skipProfile,
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
                                onPressed: () =>
                                    _handleInvite(context, flow, profile),
                                icon: const Icon(Icons.favorite),
                                label: const Text('Invite to Vibe'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton.outlined(
                              onPressed: () => showFreezeModal(context),
                              icon: const Icon(Icons.ac_unit),
                              color: FreezmeColors.primary,
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

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: false);
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
                                    child: const Text(
                                      '92% Complete',
                                      style: TextStyle(
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
                              onChanged: (value) =>
                                  setState(() => _notifications = value),
                            ),
                            const Divider(height: 32),
                            _SettingsToggleTile(
                              icon: Icons.visibility_outlined,
                              title: 'Show Online Status',
                              subtitle: 'Let matches see when you\'re active',
                              value: _showOnline,
                              onChanged: (value) =>
                                  setState(() => _showOnline = value),
                            ),
                            const Divider(height: 32),
                            _SettingsToggleTile(
                              icon: Icons.favorite_outline,
                              title: 'Read Receipts',
                              subtitle: 'Show when you\'ve read messages',
                              value: _readReceipts,
                              onChanged: (value) =>
                                  setState(() => _readReceipts = value),
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
                        onPressed: flow.signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
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
    const imageUrl =
        'https://images.unsplash.com/photo-1546961329-78bef0414d7c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx5b3VuZyUyMHdvbWFuJTIwcG9ydHJhaXR8ZW58MXx8fHwxNzYwOTQ2MDQ5fDA&ixlib=rb-4.1.0&q=80&w=1080';

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
                const Text(
                  'Looking good! 💜',
                  style: TextStyle(color: FreezmeColors.muted),
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
                      SizedBox(
                        height: 320,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(imageUrl, fit: BoxFit.cover),
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
                                'Sarah, 25',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                              'Coffee enthusiast ☕ | Weekend hiker 🥾 | Always up for deep conversations about life, art, and everything in between. Looking for genuine connections with kind souls.',
                              style: TextStyle(
                                color: FreezmeColors.neutral,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Personality Type',
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
                              children: const [
                                _ChipLabel(label: '💬 Deep Conversationalist'),
                                _ChipLabel(label: '🎒 Adventurous'),
                                _ChipLabel(label: '🏠 Homebody at heart'),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const _ProfileDetailRow(
                              icon: Icons.work_outline,
                              label: 'Product Designer',
                            ),
                            const SizedBox(height: 12),
                            const _ProfileDetailRow(
                              icon: Icons.school_outlined,
                              label: 'University of Arts',
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

class _ChatScreenPageState extends State<ChatScreenPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = List<Map<String, dynamic>>.from(
    const [
      {
        'text': 'Hey! That was such a great vibe date! 💜',
        'sender': 'them',
        'timestamp': '2:30 PM',
      },
      {
        'text': 'I know right! I loved our conversation about art 🎨',
        'sender': 'me',
        'timestamp': '2:31 PM',
      },
      {
        'text': 'Same! We should definitely check out that gallery together',
        'sender': 'them',
        'timestamp': '2:32 PM',
      },
      {
        'text': 'Absolutely! How about this weekend?',
        'sender': 'me',
        'timestamp': '2:33 PM',
      },
    ],
  );

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final now = TimeOfDay.now();
    setState(() {
      _messages.add({
        'text': text,
        'sender': 'me',
        'timestamp':
            '${now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}',
      });
    });
    _controller.clear();
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
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final bool isMe = message['sender'] == 'me';
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
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
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
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['text'] as String,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : FreezmeColors.neutral,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              message['timestamp'] as String,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white70
                                    : FreezmeColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
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

enum LogoVariant { primary, white }

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
