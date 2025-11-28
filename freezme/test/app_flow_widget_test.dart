import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freezme/main.dart';
import 'package:freezme/services/melt_chat_service.dart';
import 'package:freezme/services/photo_upload_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> configureTestSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(600, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (message.contains('A RenderFlex overflowed')) {
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);
  }

  group('AppFlow critical screens', () {
    testWidgets('Auth gate is shown after splash when onboarding incomplete', (
      WidgetTester tester,
    ) async {
      await configureTestSurface(tester);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        FreezmeApp(
          controllerBuilder: () async => AppFlowController.test(
            prefs: prefs,
            photoUploadService: MockPhotoUploadService(),
            meltChatService: MockMeltChatService(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Email'), findsOneWidget);
    });

    testWidgets('Daily vibe pool renders when onboarding is complete', (
      WidgetTester tester,
    ) async {
      await configureTestSurface(tester);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'onboarding_complete': true,
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        FreezmeApp(
          controllerBuilder: () async => AppFlowController.test(
            prefs: prefs,
            photoUploadService: MockPhotoUploadService(),
            meltChatService: MockMeltChatService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('vibes are ready'), findsOneWidget);
      expect(find.text('Invite to Melt Chat'), findsOneWidget);
      expect(find.text('Level up with Freezme+'), findsOneWidget);
    });
  });
}
