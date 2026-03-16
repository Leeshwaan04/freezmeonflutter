import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
      await tester.pumpWidget(const FreezmeApp());
      await tester.pumpAndSettle();

      try {
         await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: 'bob@example.com',
          password: 'password123',
        );
      } catch (e) {
        print('ℹ️ Sign-in might have failed if user doesn\'t exist in emulator: $e');
      }
      
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 1. Check if we are in Daily Pool
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      
      // 2. Navigate to Chat (Modular Navigator uses FlowController.openChat)
      // In the test, we simulate the tap on the navigation bar
      final chatTab = find.byIcon(Icons.chat_bubble_outline_rounded);
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

      // Tap the send button
      final sendButton = find.byIcon(Icons.send);
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
