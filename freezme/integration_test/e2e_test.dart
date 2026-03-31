import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freezme/main.dart';
import 'package:freezme/services/auth_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Freezme E2E Journey', () {
    setUpAll(() async {
      // EC2 backend — no Firebase emulators needed.
      print('✅ EC2 backend integration test setup complete');
    });

    testWidgets('Chat Journey: Login as Bob and message Alice', (tester) async {
      // Pre-seed onboarding_complete so the app lands on dailyPool after login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);

      // Sign Bob in via EC2 AuthService BEFORE pumpWidget so the auth state is
      // ready when the AppFlowController initialises.
      try {
        await AuthService.instance.signInWithEmail(
          email: 'bob@example.com',
          password: 'password123',
        );
        print('✅ Bob signed in: ${AuthService.instance.currentUser?.uid}');
      } catch (e) {
        print('❌ Sign-in failed: $e');
        rethrow;
      }

      await tester.pumpWidget(const FreezmeApp());
      // pump() instead of pumpAndSettle() to bypass infinite splash animations
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));

      // Wait for Auth listener in AppFlowController to settle on dailyPool
      await tester.pump(const Duration(seconds: 2));

      // 1. Check if we are in Home/Daily Pool
      // The bottom nav has 'Chats' text
      expect(find.text('Chats'), findsOneWidget);

      // 2. Navigate to Chat
      // Tap by text is more robust than icon variant
      final chatTab = find.text('Chats');
      await tester.tap(chatTab);
      await tester.pumpAndSettle();

      // 3. Select Alice from Chat List (Assuming ChatListPage or similar is shown)
      expect(find.text('Alice'), findsWidgets);
      await tester.tap(find.text('Alice').first);
      await tester.pumpAndSettle();

      // 4. Send Message
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'Hello Alice! This is an automated E2E test message.');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      // Tap the send button (chat screen uses Icons.send_rounded)
      final sendButton = find.byIcon(Icons.send_rounded);
      if (sendButton.evaluate().isNotEmpty) {
        await tester.tap(sendButton);
        await tester.pumpAndSettle();
      }

      // 5. Verify message
      expect(find.text('Hello Alice! This is an automated E2E test message.'), findsOneWidget);
      print('✅ Message sent and verified in history');

      // 6. Exit Chat
      final backButton = find.byIcon(Icons.chevron_left);
      await tester.tap(backButton);
      await tester.pumpAndSettle();
    });
  });
}
