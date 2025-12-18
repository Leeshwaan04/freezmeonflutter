import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'main.dart';
import 'ui/onboarding/enhanced_onboarding.dart';
import 'ui/profile/profile_completion_page.dart';
import 'ui/home/home_page.dart';
import 'ui/chat/chat_list_page.dart';
import 'ui/paths/paths_page.dart';
import 'ui/blinds/blinds_page.dart';
import 'ui/chat/chat_screen_page.dart';
import 'ui/match_success/match_success_page.dart';
import 'ui/profile/profile_preview_page.dart';
import 'ui/profile/edit_profile_page.dart';
import 'ui/recap/daily_recap_page.dart';
import 'ui/profile/profile_settings_page.dart';
import 'ui/settings/freezme_plus_page.dart';

/// Production-ready router configuration using go_router
/// This replaces the custom FlowNavigator to fix widget tree lifecycle issues
class FreezmeRouter {
  final AppFlowController flow;

  FreezmeRouter(this.flow);

  late final GoRouter router = GoRouter(
    debugLogDiagnostics: false,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: AuthGatePage(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: EnhancedOnboardingFlow(),
        ),
      ),
      GoRoute(
        path: '/profile-completion',
        name: 'profile-completion',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: ProfileCompletionPage(),
        ),
      ),
      GoRoute(
        path: '/daily-pool',
        name: 'daily-pool',
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: HomePage(),
        ),
      ),
      GoRoute(
        path: '/chat-list',
        name: 'chat-list',
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: ChatListPage(),
        ),
      ),
      GoRoute(
        path: '/paths',
        name: 'paths',
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: PathsPage(),
        ),
      ),
      GoRoute(
        path: '/blinds',
        name: 'blinds',
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: BlindsPage(),
        ),
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: ChatScreenPage(),
        ),
      ),
      GoRoute(
        path: '/match-success',
        name: 'match-success',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: MatchSuccessPage(),
        ),
      ),
      GoRoute(
        path: '/profile-preview',
        name: 'profile-preview',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: ProfilePreviewPage(),
        ),
      ),
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: EditProfilePage(),
        ),
      ),
      GoRoute(
        path: '/daily-recap',
        name: 'daily-recap',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: DailyRecapPage(),
        ),
      ),
      GoRoute(
        path: '/profile-settings',
        name: 'profile-settings',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: ProfileSettingsPage(),
        ),
      ),
      GoRoute(
        path: '/freezme-plus',
        name: 'freezme-plus',
        pageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: FreezmePlusPage(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: Colors.red,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Navigation Error',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  state.error.toString(),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.go('/splash'),
                  child: Text('Return to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  /// Map AppStage to route path
  String? _stageToPath(AppStage stage) {
    switch (stage) {
      case AppStage.splash:
        return '/splash';
      case AppStage.authGate:
        return '/auth';
      case AppStage.onboarding:
        return '/onboarding';
      case AppStage.profileCompletion:
        return '/profile-completion';
      case AppStage.dailyPool:
        return '/daily-pool';
      case AppStage.chatList:
        return '/chat-list';
      case AppStage.paths:
        return '/paths';
      case AppStage.blinds:
        return '/blinds';
      case AppStage.chat:
        return '/chat';
      case AppStage.matchSuccess:
        return '/match-success';
      case AppStage.profilePreview:
        return '/profile-preview';
      case AppStage.editProfile:
        return '/edit-profile';
      case AppStage.dailyRecap:
        return '/daily-recap';
      case AppStage.profileSettings:
        return '/profile-settings';
      case AppStage.freezmePlus:
        return '/freezme-plus';
      case AppStage.developerMenu:
        return null; // Developer menu not exposed in router
    }
  }

  /// Create a fade transition page for tab navigation
  Page _fadePage({required LocalKey key, required Widget child}) {
    return CustomTransitionPage(
      key: key,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }
}
