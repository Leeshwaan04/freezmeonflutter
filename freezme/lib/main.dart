import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'ui/theme.dart';
import 'controllers/flow_controller.dart';
import 'core/app_stage.dart';
import 'data/firestore_freezme_repository.dart';
import 'data/mock_freezme_repository.dart';

// Re-export controller and stages so UI files that import main.dart stay compiling.
export 'controllers/flow_controller.dart' show AppFlowController, AppFlowScope;
export 'core/app_stage.dart';
export 'models/photo_slot.dart';

// Screen Imports
import 'ui/screens/splash_screen.dart';
import 'ui/screens/auth_gate.dart';
import 'ui/screens/onboarding_flow.dart';
import 'ui/screens/compatibility_quiz.dart';
import 'ui/screens/daily_vibe_pool.dart';
import 'ui/home/home_page.dart';
import 'ui/screens/video_date.dart';
import 'ui/screens/match_success.dart';
import 'ui/screens/chat_screen.dart';
import 'ui/profile/profile_settings_page.dart';
import 'ui/screens/profile_preview.dart';
import 'ui/screens/daily_recap.dart';
import 'ui/screens/freezme_plus.dart' show FreezeMePlusPage;
import 'ui/screens/developer_preview.dart';
import 'ui/screens/freeze_screen.dart';
import 'ui/screens/verification_screen.dart';
import 'ui/screens/vector_simulation.dart';
import 'ui/screens/circle_discovery.dart';
import 'ui/screens/circle_chat.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crashlytics — capture uncaught Flutter + platform errors in release builds
  if (!kDebugMode) {
    FlutterError.onError = (errorDetails) {
       FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    
    // Fallback UI for production crashes (no Red Screen of Death)
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.grey, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'We have been notified and are working on it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () { 
                    // Simple way to restart or go back
                  },
                  child: const Text('Return to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    };
  }

  runApp(const FreezmeApp());
}

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
            FirestoreFreezmeRepository(fallback: const MockFreezmeRepository()));

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
  final Widget Function(BuildContext, Animation<double>, Animation<double>, Widget) transitionsBuilder;

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
          for (final stage in flow.stack)
            _FreezmeTransitionPage<dynamic>(
              key: ValueKey<AppStage>(stage),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
            flow.pop();
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
        return const HomePage();
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
      case AppStage.freeze:
        return const FreezeScreen();
      case AppStage.verification:
        return const VerificationScreen();
      case AppStage.vectorSimulation:
        return const VectorSimulationScreen();
      case AppStage.circleDiscovery:
        return const CircleDiscoveryPage();
      case AppStage.circleChat:
        return const CircleChatPage();
      case AppStage.profileCompletion:
        return const OnboardingFlowPage();
      case AppStage.editProfile:
        return const ProfileSettingsPage();
    }
  }
}
