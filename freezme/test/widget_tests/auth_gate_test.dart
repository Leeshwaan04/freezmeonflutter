import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freezme/main.dart';
import 'package:freezme/services/melt_chat_service.dart';
import 'package:freezme/services/photo_upload_service.dart';
import 'package:freezme/services/iap_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../mocks/mock_repository.dart';

// ── Fake IAP ──────────────────────────────────────────────────────────────────
class _FakeIAP implements IAPService {
  @override Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();
  @override Future<bool> isAvailable() async => false;
  @override Future<List<ProductDetails>> fetchProducts(Set<String> ids) async => [];
  @override Future<void> buyProduct(ProductDetails product) async {}
  @override Future<void> restorePurchases() async {}
  @override void dispose() {}
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<void> setSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // Suppress overflow errors in tests (animations, small surface)
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('RenderFlex overflowed')) return;
    original?.call(d);
  };
  addTearDown(() => FlutterError.onError = original);
}

Future<void> pumpApp(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  await tester.pumpWidget(FreezmeApp(
    controllerBuilder: () async => AppFlowController.test(
      prefs: p,
      photoUploadService: MockPhotoUploadService(),
      meltChatService: MockMeltChatService(),
      repository: MockFreezmeRepository(),
      iapService: _FakeIAP(),
    ),
  ));
}

// ── Auth Gate Widget Tests ────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Gate — Unauthenticated State', () {
    testWidgets('shows FREEZME branding on auth screen', (tester) async {
      await setSurface(tester);
      await pumpApp(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));

      // FREEZME wordmark should be visible
      expect(find.text('FREEZME'), findsWidgets);
    });

    testWidgets('shows Continue with Apple button', (tester) async {
      await setSurface(tester);
      await pumpApp(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));

      expect(find.textContaining('Apple'), findsOneWidget);
    });

    testWidgets('shows Continue with Google button', (tester) async {
      await setSurface(tester);
      await pumpApp(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));

      expect(find.textContaining('Google'), findsOneWidget);
    });

    testWidgets('shows Continue with Email button', (tester) async {
      await setSurface(tester);
      await pumpApp(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));

      expect(find.textContaining('Email'), findsOneWidget);
    });

    testWidgets('tapping Email opens bottom sheet with email/password fields', (tester) async {
      await setSurface(tester);
      await pumpApp(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));

      final emailBtn = find.textContaining('Email');
      if (emailBtn.evaluate().isNotEmpty) {
        await tester.tap(emailBtn.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Bottom sheet with fields should appear
        expect(find.byType(TextField), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('email bottom sheet has Create Account and Sign In tabs', (tester) async {
      await setSurface(tester);
      await pumpApp(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));

      final emailBtn = find.textContaining('Email');
      if (emailBtn.evaluate().isNotEmpty) {
        await tester.tap(emailBtn.first);
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.textContaining('Create Account'), findsWidgets);
        expect(find.textContaining('Sign In'), findsWidgets);
      }
    });

    testWidgets('tagline is visible', (tester) async {
      await setSurface(tester);
      await pumpApp(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));

      expect(
        find.textContaining('Compatibility') |
        find.textContaining('Connection') |
        find.textContaining('vibe'),
        findsWidgets,
      );
    });
  });

  group('Auth Gate — No Developer Preview Button', () {
    testWidgets('Developer Preview button is NOT shown in production', (tester) async {
      await setSurface(tester);
      await pumpApp(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));

      expect(find.textContaining('Developer'), findsNothing);
      expect(find.textContaining('Preview'), findsNothing);
    });
  });
}
