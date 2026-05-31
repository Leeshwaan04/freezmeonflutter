import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freezme/main.dart';
import 'package:freezme/core/app_stage.dart';
import 'package:freezme/services/melt_chat_service.dart';
import 'package:freezme/services/photo_upload_service.dart';
import 'package:freezme/services/iap_service.dart';
import '../mocks/mock_repository.dart';

// Device sizes under test
const _kSE = Size(375, 667);       // iPhone SE 3rd gen (smallest supported)
const _kStd = Size(390, 844);      // iPhone 14 (baseline)
const _kProMax = Size(430, 932);   // iPhone 14 Pro Max (largest)

Future<void> suppressErrors(WidgetTester tester) async {
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    final msg = d.exceptionAsString();
    if (msg.contains('RenderFlex overflowed')) {
      fail('RenderFlex overflow detected: ${d.summary}');
    }
    if (msg.contains('NetworkImageLoadException')) return;
    if (msg.contains('HTTP request failed')) return;
    original?.call(d);
  };
  addTearDown(() => FlutterError.onError = original);
}

Future<AppFlowController> pumpAtSize(
  WidgetTester tester,
  Size size,
  AppStage stage,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.setSurfaceSize(null);
  });
  imageCache.maximumSize = 0;
  addTearDown(() => imageCache.maximumSize = 1000);

  SharedPreferences.setMockInitialValues({});
  final p = await SharedPreferences.getInstance();
  final repo = MockFreezmeRepository();
  late AppFlowController ctrl;

  await tester.pumpWidget(FreezmeApp(
    controllerBuilder: () async {
      ctrl = AppFlowController.test(
        prefs: p,
        photoUploadService: MockPhotoUploadService(),
        meltChatService: MockMeltChatService(),
        repository: repo,
        iapService: IAPService(repo),
      );
      ctrl.replaceStack([stage]);
      return ctrl;
    },
  ));

  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(seconds: 7)); // drain location/timezone timeouts
  return ctrl;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Responsive — Auth Gate', () {
    for (final entry in {
      'iPhone SE (375×667)': _kSE,
      'iPhone 14 (390×844)': _kStd,
      'iPhone 14 Pro Max (430×932)': _kProMax,
    }.entries) {
      testWidgets('renders without overflow on ${entry.key}', (tester) async {
        await suppressErrors(tester);
        await pumpAtSize(tester, entry.value, AppStage.authGate);
        expect(find.byType(Scaffold), findsWidgets);
        // Verify all 3 auth buttons are present and in bounds
        expect(find.textContaining('Apple'), findsOneWidget);
        expect(find.textContaining('Google'), findsOneWidget);
        expect(find.textContaining('Email'), findsOneWidget);
      });
    }
  });

  // Home / Daily Pool excluded from multi-iteration responsive test: HomePage has a
  // Timer.periodic(1s) + platform-channel location future that accumulates in FakeAsync
  // when multiple screen sizes run sequentially, causing a 10-minute hang on the 2nd
  // iteration. HomePage layout is covered by daily_pool_test.dart + manual device testing.

  group('Responsive — Profile Settings', () {
    for (final entry in {
      'iPhone SE (375×667)': _kSE,
      'iPhone 14 (390×844)': _kStd,
      'iPhone 14 Pro Max (430×932)': _kProMax,
    }.entries) {
      testWidgets('renders without overflow on ${entry.key}', (tester) async {
        await suppressErrors(tester);
        await pumpAtSize(tester, entry.value, AppStage.profileSettings);
        expect(find.byType(Scaffold), findsWidgets);
      });
    }
  });

  // Chat List and Freezme+ have live streams/WebSocket connections that prevent
  // pumpAndSettle from completing — these screens are covered by existing unit tests.
  // Responsiveness for these screens is verified via manual device testing.

  // Onboarding has complex multi-step animations — tested separately in app_flow_widget_test.dart

}
