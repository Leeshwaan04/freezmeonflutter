import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:freezme/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Freezme E2E Journey', () {
    setUpAll(() async {
      const String host = '127.0.0.1';
      try {
        await Firebase.initializeApp();
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8085);
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
        print('✅ Firebase Emulators Connected');
      } catch (e) {
        print('⚠️ Firebase already initialized or emulator connection failed: $e');
      }
    });

    testWidgets('Chat Journey: Login as Bob and message Alice', (tester) async {
      // Pre-seed onboarding_complete so the app lands on dailyPool after login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);

      // Disable app verification (bypasses APNs checks on iOS simulator)
      await FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: true);

      // Sign Bob in BEFORE pumpWidget so the auth state is ready when the
      // AppFlowController initialises and calls _listenToAuth().
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: 'bob@example.com',
          password: 'password123',
        );
        print('✅ Bob signed in: ${FirebaseAuth.instance.currentUser?.uid}');
      } on FirebaseAuthException catch (e) {
        print('❌ FirebaseAuthException code=${e.code} msg=${e.message}');
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
      // Note: In modular version, ChatScreenPage is shown via Navigator stack.
      // If Alice is mocked in Daily Pool, we might need a different selector.
      // For now, let's look for Alice.
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
