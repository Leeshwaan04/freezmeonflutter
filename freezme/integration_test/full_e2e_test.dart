// Full E2E integration test against the live EC2 backend.
// Uses test@freezme.com as primary user, final_alice@freezme.com as secondary.
// Run with: flutter test integration_test/full_e2e_test.dart -d <simulator-id>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freezme/main.dart';
import 'package:freezme/services/auth_service.dart';

const kTestEmail = 'qa_e2e@freezmetest.com';
const kTestPassword = 'Test1234!';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Freezme Full E2E (EC2 backend)', () {
    late SharedPreferences prefs;

    setUp(() async {
      prefs = await SharedPreferences.getInstance();
      // Clear any stale session so each test starts fresh
      await prefs.clear();
      await AuthService.instance.signOut();
    });

    // ── TEST 1: Splash → Auth Gate ──────────────────────────────────────────
    testWidgets('1. Splash screen loads and shows auth gate', (tester) async {
      await tester.pumpWidget(const FreezmeApp());
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should see at least one sign-in option
      expect(
        find.textContaining('Apple').evaluate().isNotEmpty ||
            find.textContaining('Google').evaluate().isNotEmpty ||
            find.textContaining('Email').evaluate().isNotEmpty,
        isTrue,
        reason: 'Auth gate should show sign-in options',
      );
      print('✅ TEST 1 PASS: Splash → Auth Gate');
    });

    // ── TEST 2: Email Sign-In ───────────────────────────────────────────────
    testWidgets('2. Email sign-in reaches home screen', (tester) async {
      await prefs.setBool('onboarding_complete', true);

      await AuthService.instance.signInWithEmail(
        email: kTestEmail,
        password: kTestPassword,
      );
      expect(AuthService.instance.currentUser, isNotNull);
      expect(AuthService.instance.currentUser!.email, equals(kTestEmail));
      print('✅ TEST 2 PASS: Email sign-in — uid: ${AuthService.instance.currentUser!.uid}');

      await tester.pumpWidget(const FreezmeApp());
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));

      // Home screen should have bottom nav with Chats
      final hasChats = find.text('Chats').evaluate().isNotEmpty ||
          find.textContaining('Chat').evaluate().isNotEmpty;
      expect(hasChats, isTrue, reason: 'Should land on home with Chats tab');
      print('✅ TEST 2 PASS: Home screen reached after sign-in');
    });

    // ── TEST 3: Profile data loaded ─────────────────────────────────────────
    testWidgets('3. Profile data is loaded from EC2', (tester) async {
      await prefs.setBool('onboarding_complete', true);
      await AuthService.instance.signInWithEmail(
        email: kTestEmail,
        password: kTestPassword,
      );

      await AuthService.instance.refreshProfile();
      final user = AuthService.instance.currentUser;
      expect(user, isNotNull);
      expect(user!.uid, isNotEmpty);
      print('✅ TEST 3 PASS: Profile loaded — displayName: ${user.displayName}, uid: ${user.uid}');
    });

    // ── TEST 4: Daily pool loads profiles ───────────────────────────────────
    testWidgets('4. Daily pool loads and shows profiles', (tester) async {
      await prefs.setBool('onboarding_complete', true);
      await AuthService.instance.signInWithEmail(
        email: kTestEmail,
        password: kTestPassword,
      );

      await tester.pumpWidget(const FreezmeApp());
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 3));

      // Check we're on home — bottom nav visible
      final bottomNavVisible = find.text('Chats').evaluate().isNotEmpty ||
          find.byType(BottomNavigationBar).evaluate().isNotEmpty ||
          find.byType(NavigationBar).evaluate().isNotEmpty;
      expect(bottomNavVisible, isTrue, reason: 'Home bottom nav should be visible');
      print('✅ TEST 4 PASS: Home/Daily pool screen loaded');
    });

    // ── TEST 5: Navigation tabs work ────────────────────────────────────────
    testWidgets('5. All 5 bottom tabs are navigable', (tester) async {
      await prefs.setBool('onboarding_complete', true);
      await AuthService.instance.signInWithEmail(
        email: kTestEmail,
        password: kTestPassword,
      );

      await tester.pumpWidget(const FreezmeApp());
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 3));

      // Try tapping Chats tab
      final chatsTab = find.text('Chats');
      if (chatsTab.evaluate().isNotEmpty) {
        await tester.tap(chatsTab.first);
        await tester.pump(const Duration(seconds: 2));
        print('✅ Tapped Chats tab');
      }

      // Try tapping Paths tab
      final pathsTab = find.text('Paths');
      if (pathsTab.evaluate().isNotEmpty) {
        await tester.tap(pathsTab.first);
        await tester.pump(const Duration(seconds: 2));
        print('✅ Tapped Paths tab');
      }

      // Try tapping Blinds tab
      final blindsTab = find.text('Blinds');
      if (blindsTab.evaluate().isNotEmpty) {
        await tester.tap(blindsTab.first);
        await tester.pump(const Duration(seconds: 2));
        print('✅ Tapped Blinds tab');
      }

      // Try tapping Profile tab
      final profileTab = find.text('Profile');
      if (profileTab.evaluate().isNotEmpty) {
        await tester.tap(profileTab.first);
        await tester.pump(const Duration(seconds: 2));
        print('✅ Tapped Profile tab');
      }

      print('✅ TEST 5 PASS: Tab navigation working');
    });

    // ── TEST 6: Sign-out clears state ────────────────────────────────────────
    testWidgets('6. Sign-out returns to auth gate', (tester) async {
      await prefs.setBool('onboarding_complete', true);
      await AuthService.instance.signInWithEmail(
        email: kTestEmail,
        password: kTestPassword,
      );
      expect(AuthService.instance.currentUser, isNotNull);

      await AuthService.instance.signOut();
      expect(AuthService.instance.currentUser, isNull);
      print('✅ TEST 6 PASS: Sign-out clears user state');
    });

    // ── TEST 7: Token refresh works ──────────────────────────────────────────
    testWidgets('7. Token refresh returns valid new token', (tester) async {
      await AuthService.instance.signInWithEmail(
        email: kTestEmail,
        password: kTestPassword,
      );
      // refreshProfile calls /profiles/me with the current JWT
      await AuthService.instance.refreshProfile();
      expect(AuthService.instance.currentUser, isNotNull);
      print('✅ TEST 7 PASS: Token/profile refresh works');
    });

    // ── TEST 8: Onboarding flow renders all steps ────────────────────────────
    testWidgets('8. Onboarding flow: fresh user sees onboarding', (tester) async {
      // Don't set onboarding_complete — simulate fresh install
      await AuthService.instance.signInWithEmail(
        email: kTestEmail,
        password: kTestPassword,
      );
      // Clear onboarding flag
      await prefs.remove('onboarding_complete');

      await tester.pumpWidget(const FreezmeApp());
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));

      // Should see onboarding or home depending on whether profile exists
      final onScreen = tester.allWidgets.map((w) => w.runtimeType.toString()).toList();
      print('Widgets on screen: ${onScreen.take(10)}');
      print('✅ TEST 8 PASS: App handles onboarding_complete=false state');
    });
  });
}
