import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'ui/theme.dart';
import 'core/database.dart';
import 'controllers/flow_controller.dart';
import 'core/app_stage.dart';
import 'data/ec2_freezme_repository.dart';
import 'data/mock_freezme_repository.dart';
import 'services/auth_service.dart';
import 'services/api_client.dart';
import 'services/localization_service.dart';
import 'services/push_notification_service.dart';
import 'services/websocket_service.dart';
import 'models/vibe_profile.dart';

// Re-export controller and stages so UI files that import main.dart stay compiling.
export 'controllers/flow_controller.dart' show AppFlowController, AppFlowScope;
export 'core/app_stage.dart';
export 'models/photo_slot.dart';

// Screen Imports
import 'ui/screens/splash_screen.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/screens/auth_gate.dart';
import 'ui/screens/onboarding_flow.dart';
import 'ui/home/home_page.dart';
import 'ui/screens/match_success.dart';
import 'ui/chat/chat_screen_page.dart';
import 'ui/profile/profile_settings_page.dart';
import 'ui/screens/profile_preview.dart';
import 'ui/screens/daily_recap.dart';
import 'ui/settings/freezme_plus_page.dart';
import 'ui/screens/developer_preview.dart';
import 'ui/screens/freeze_screen.dart';
import 'ui/screens/verification_screen.dart';
import 'ui/screens/vector_simulation.dart';
import 'ui/freeze_room/freeze_room_page.dart';
import 'ui/profile/profile_level_up_flow.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Push] background message: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handlers — present errors in debug, swallow them quietly in
  // release. Sentry (when DSN is set) will already hook FlutterError.onError
  // via SentryFlutter.init, so we install these only when Sentry is absent.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (!kDebugMode) {
      debugPrint('[FlutterError] ${details.exceptionAsString()}');
    }
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[PlatformError] $error');
    // Return false so the platform crash reporter (TestFlight, Crashlytics) still
    // receives the signal. Sentry hooks this separately when its DSN is configured.
    return false;
  };

  // Wrap initialization in a fail-safe timeout to prevent white screen hangs
  try {
    await Future.wait([
      LocalDatabase.init().timeout(const Duration(seconds: 2)),
      LocalizationService().initialize().timeout(const Duration(seconds: 2)),
      AuthService.instance.init().timeout(const Duration(seconds: 3)),
      AuthService.initGoogleSignIn().timeout(const Duration(seconds: 3)),
      Firebase.initializeApp().timeout(const Duration(seconds: 3)).then((_) {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        unawaited(PushNotificationService().initialize());
      }),
    ]).timeout(const Duration(seconds: 5), onTimeout: () {
      debugPrint('[Init] Warning: Initialization timed out. Booting UI anyway.');
      return [];
    });
  } catch (e) {
    debugPrint('[Init] Error during bootstrap: $e');
  }

  // Connect WebSocket if already logged in
  try {
    final loggedIn = await ApiClient.instance.isLoggedIn.timeout(const Duration(seconds: 2));
    if (loggedIn) {
      unawaited(WebSocketService.instance.connect());
      unawaited(PushNotificationService().initialize());
    }
  } catch (_) {}

  const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  if (sentryDsn.isNotEmpty && !kDebugMode) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.2;
        options.environment = 'production';
        // Compile-time release tag so crashes can be attributed to a build.
        // CI should pass --dart-define=APP_RELEASE=freezme@<version>+<build>.
        const release = String.fromEnvironment('APP_RELEASE');
        if (release.isNotEmpty) options.release = release;
      },
      appRunner: () => runApp(const FreezmeApp()),
    );
  } else {
    runApp(const FreezmeApp());
  }
}

// ignore: prefer_void_to_null
Future<Null> unawaited(Future<void> future) => future.then((_) => null);

class FreezmeApp extends StatefulWidget {
  const FreezmeApp({this.controllerBuilder, super.key});

  final Future<AppFlowController> Function()? controllerBuilder;

  @override
  State<FreezmeApp> createState() => _FreezmeAppState();
}

class _FreezmeAppState extends State<FreezmeApp> {
  AppFlowController? _controller;

  @override
  void initState() {
    super.initState();
    final builder = widget.controllerBuilder ??
        () => AppFlowController.create(
            Ec2FreezmeRepository(fallback: const MockFreezmeRepository()));

    builder().then((controller) {
      if (mounted) {
        setState(() {
          _controller = controller;
        });
        // Now that the flow controller exists, route any pending or future
        // push-notification taps to the relevant stage.
        PushNotificationService().registerTapHandler((data) {
          _routePushTap(controller, data);
        });
      }
    });
  }

  /// Maps an FCM data payload to a navigation action on the flow controller.
  /// Server emits { type, chatId, senderUid, senderName, senderPhoto } for chat
  /// pushes; everything else routes to the daily pool home.
  void _routePushTap(AppFlowController flow, Map<String, dynamic> data) {
    final type = (data['type'] as String?)?.toLowerCase();
    if (type == null) return;

    if (type == 'chat_message' || type == 'chat') {
      final chatId = data['chatId'] as String?;
      final senderUid = data['senderUid'] as String?;
      final senderName = data['senderName'] as String? ?? 'Match';
      final senderPhoto = data['senderPhoto'] as String? ?? '';

      if (chatId != null && senderUid != null) {
        // Open directly into the correct conversation.
        flow.openHome();
        flow.openChatDetail(
          VibeProfile(
            uid: senderUid,
            name: senderName,
            imageUrl: senderPhoto,
            age: 0,
            compatibility: 0,
            bio: '',
            distance: '',
          ),
          chatId: chatId,
        );
        return;
      }
      // Fallback: no chatId in payload — open chats tab.
      flow.openHome();
      flow.openTab(1);
    } else if (type == 'match') {
      flow.openHome();
      flow.openTab(1);
    } else {
      flow.openHome();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    WebSocketService.instance.dispose();
    AuthService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
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

class _FreezmeTransitionPage<T> extends Page<T> {
  const _FreezmeTransitionPage({
    required this.child,
    required this.transitionsBuilder,
    super.key,
  });

  final Widget child;
  final Widget Function(BuildContext, Animation<double>, Animation<double>,
      Widget) transitionsBuilder;

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: transitionsBuilder,
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
          for (final (index, stage) in flow.stack.indexed)
            _FreezmeTransitionPage<dynamic>(
              key: ValueKey<String>('${stage.name}_$index'),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: animation.drive(Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOutQuart))),
                    child: child,
                  ),
                );
              },
              child: _buildStage(context, stage),
            ),
        ];

        return Navigator(
          pages: pages,
          onDidRemovePage: (page) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              flow.pop();
            });
          },
        );
      },
    );
  }

  Widget _buildStage(BuildContext context, AppStage stage) {
    switch (stage) {
      case AppStage.splash:
        return const SplashScreen();
      case AppStage.welcome:
        return const WelcomeScreen();
      case AppStage.authGate:
        return const AuthGatePage();
      case AppStage.onboarding:
        return const OnboardingFlowPage();
      case AppStage.dailyPool:
        return const HomePage();
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
        return const FreezmePlusPage();
      case AppStage.developerMenu:
        return const DeveloperPreviewScreen();
      case AppStage.freeze:
        return const FreezeScreen();
      case AppStage.verification:
        return const VerificationScreen();
      case AppStage.vectorSimulation:
        return const VectorSimulationScreen();
      case AppStage.profileCompletion:
        return const OnboardingFlowPage();
      case AppStage.editProfile:
        return const ProfileSettingsPage();
      case AppStage.freezeRoom:
        return const FreezeRoomPage();
      case AppStage.levelUp:
        return const ProfileLevelUpFlow();
    }
  }
}
