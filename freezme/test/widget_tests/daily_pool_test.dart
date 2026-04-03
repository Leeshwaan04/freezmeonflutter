import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freezme/main.dart';
import 'package:freezme/core/app_stage.dart';
import 'package:freezme/services/melt_chat_service.dart';
import 'package:freezme/services/photo_upload_service.dart';
import 'package:freezme/services/iap_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../mocks/mock_repository.dart';

class _FakeIAP implements IAPService {
  @override Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();
  @override Future<bool> isAvailable() async => false;
  @override Future<List<ProductDetails>> fetchProducts(Set<String> ids) async => [];
  @override Future<void> buyProduct(ProductDetails product) async {}
  @override Future<void> restorePurchases() async {}
  @override void dispose() {}
}

Future<void> setSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('RenderFlex overflowed')) return;
    original?.call(d);
  };
  addTearDown(() => FlutterError.onError = original);
}

Future<AppFlowController> pumpToDailyPool(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final p = await SharedPreferences.getInstance();
  late AppFlowController ctrl;
  await tester.pumpWidget(FreezmeApp(
    controllerBuilder: () async {
      ctrl = AppFlowController.test(
        prefs: p,
        photoUploadService: MockPhotoUploadService(),
        meltChatService: MockMeltChatService(),
        repository: MockFreezmeRepository(),
        iapService: _FakeIAP(),
      );
      ctrl.replaceStack([AppStage.dailyPool]);
      return ctrl;
    },
  ));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(seconds: 2));
  return ctrl;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Daily Pool Screen', () {
    testWidgets('renders without crashing', (tester) async {
      await setSurface(tester);
      await pumpToDailyPool(tester);
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('shows bottom navigation bar', (tester) async {
      await setSurface(tester);
      await pumpToDailyPool(tester);
      final hasNav = find.byType(BottomNavigationBar).evaluate().isNotEmpty ||
                     find.byType(NavigationBar).evaluate().isNotEmpty ||
                     find.byType(NavigationBarTheme).evaluate().isNotEmpty;
      expect(hasNav, isTrue);
    });

    testWidgets('displays mock profiles from MockFreezmeRepository', (tester) async {
      await setSurface(tester);
      await pumpToDailyPool(tester);
      await tester.pump(const Duration(seconds: 1));

      // MockRepository returns Alex and Jordan
      final hasProfile = find.textContaining('Alex').evaluate().isNotEmpty ||
                         find.textContaining('Jordan').evaluate().isNotEmpty;
      expect(hasProfile, isTrue);
    });

    testWidgets('shows FREEZME logo', (tester) async {
      await setSurface(tester);
      await pumpToDailyPool(tester);
      expect(find.text('FREEZME'), findsWidgets);
    });
  });

  group('Bottom Navigation', () {
    testWidgets('navigating to Chats tab does not crash', (tester) async {
      await setSurface(tester);
      final ctrl = await pumpToDailyPool(tester);
      ctrl.push(AppStage.chats);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('navigating to Paths tab does not crash', (tester) async {
      await setSurface(tester);
      final ctrl = await pumpToDailyPool(tester);
      ctrl.push(AppStage.paths);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('navigating to Profile Settings does not crash', (tester) async {
      await setSurface(tester);
      final ctrl = await pumpToDailyPool(tester);
      ctrl.push(AppStage.profileSettings);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
}
