import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freezme/main.dart';
import 'package:freezme/services/melt_chat_service.dart';
import 'package:freezme/services/photo_upload_service.dart';
import 'package:freezme/data/mock_freezme_repository.dart';
import 'package:freezme/services/iap_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('User can complete onboarding and reach home', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(1080, 2160));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      FreezmeApp(
        controllerBuilder: () async => AppFlowController.test(
          prefs: prefs,
          photoUploadService: MockPhotoUploadService(),
          meltChatService: MockMeltChatService(),
          repository: const MockFreezmeRepository(),
          iapService: IAPService(const MockFreezmeRepository()),
        ),
      ),
    );

    // Wait for controller to initialise (splash → authGate)
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Bypass auth gate — directly start onboarding via the flow controller.
    // FlowNavigator is a child of AppFlowScope so of() resolves correctly.
    final flowElement = tester.element(find.byType(FlowNavigator));
    AppFlowScope.of(flowElement, listen: false).startOnboarding();
    await tester.pumpAndSettle();

    // ── Step 1: Intent ────────────────────────────────────────────────────────
    expect(find.text('What are you looking for?'), findsOneWidget);
    expect(find.textContaining('Step 1 of 6'), findsOneWidget);

    // Select intent (shown as enum.name.toUpperCase())
    await tester.tap(find.text('MEANINGFUL'));
    await tester.pump();

    // Confirm 18+ age gate checkbox
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // ── Step 2: Personality Traits ────────────────────────────────────────────
    expect(find.text('Describe your vibe'), findsOneWidget);

    // Select at least one FilterChip (shown as trait.name)
    await tester.tap(find.text('adventurous'));
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // ── Step 3: Lifestyle ─────────────────────────────────────────────────────
    expect(find.text('Your Lifestyle'), findsOneWidget);

    // Select at least one (shown as factor.name.toUpperCase())
    await tester.tap(find.text('FITNESS'));
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // ── Step 4: Interests (need ≥ 3) ─────────────────────────────────────────
    expect(find.text('Passions'), findsOneWidget);

    await tester.tap(find.text('Music'));
    await tester.pump();
    await tester.tap(find.text('Art'));
    await tester.pump();
    await tester.tap(find.text('Coffee'));
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // ── Step 5: Voice Intro (optional — just continue) ────────────────────────
    expect(find.text('Voice Introduction'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // ── Step 6: Profile — enter age and bio ──────────────────────────────────
    expect(find.text('Almost there!'), findsOneWidget);

    // Two TextFields: age first, bio second
    await tester.enterText(find.byType(TextField).first, '25');
    await tester.pump();
    await tester.enterText(
      find.byType(TextField).last,
      'Hello! Automated E2E test bio for Freezme.',
    );
    await tester.pump();

    await tester.tap(find.text('Finalize'));
    await tester.pumpAndSettle();

    // ── Archetype reveal → proceed to home ───────────────────────────────────
    expect(find.text('YOUR DATING PERSONALITY'), findsOneWidget);

    await tester.tap(find.text("Let's Go!"));
    await tester.pumpAndSettle();

    // ── Home page — bottom nav confirms we landed on daily pool ───────────────
    expect(find.text('Chats'), findsOneWidget);
  });
}
