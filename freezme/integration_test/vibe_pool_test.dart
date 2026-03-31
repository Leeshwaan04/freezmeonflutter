import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:freezme/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E: Daily Vibe Pool Journey', () {
    testWidgets('Verify discovery and matching flow', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 1. Enter Developer Preview to skip real auth
      final devPreviewButton = find.text('Open Developer Preview');
      expect(devPreviewButton, findsOneWidget);
      await tester.tap(devPreviewButton);
      await tester.pumpAndSettle();

      // 2. Select 'Daily Vibe Pool' from the design menu
      final vibePoolButton = find.text('Daily Vibe Pool');
      await tester.tap(vibePoolButton);
      await tester.pumpAndSettle();

      // 3. Verify screen identity components
      expect(find.text('TONIGHT\'S POOL'), findsOneWidget);
      expect(find.text('Priya, 24'), findsOneWidget);
      expect(find.text('Alex, 27'), findsOneWidget);

      // 4. Test Interaction: Heart Button for Priya
      final heartButtons = find.byIcon(Icons.favorite_border);
      expect(heartButtons, findsAtLeastNWidgets(2));
      
      // Tap the first heart (Priya)
      await tester.tap(heartButtons.first);
      await tester.pump(const Duration(milliseconds: 500)); // Animation delay

      // 5. Verify Navigation Consistency
      expect(find.byIcon(Icons.explore), findsOneWidget); // Tonight
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget); // Chats
      expect(find.byIcon(Icons.bolt), findsOneWidget); // Blinds

      print('✅ Daily Vibe Pool E2E Journey Passed: UI integrity confirmed.');
    });
  Group('Navigation: Bottom Bar Integrity', () {
    testWidgets('Verify context switching', (tester) async {
      // (Repeat setup)
      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pumpAndSettle();
      // Should show chat screen
    });
  });
});
}
