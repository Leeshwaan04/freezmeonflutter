import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freezme/main.dart';
import 'package:freezme/services/melt_chat_service.dart';
import 'package:freezme/services/photo_upload_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('User can complete onboarding and compatibility quiz', (
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
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Apple'));
    await tester.pumpAndSettle();

    expect(find.text('What brings you here?'), findsOneWidget);
    expect(find.textContaining('Step 1 of 3'), findsOneWidget);

    await tester.tap(find.text('Meaningful connection'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(ValueKey('photo-slot-$i')));
      await tester.pump(const Duration(milliseconds: 400));
    }

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final slider = find.byType(Slider);
    for (var i = 0; i < 9; i++) {
      await tester.drag(slider.first, const Offset(40, 0));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    await tester.drag(slider.first, const Offset(-30, 0));
    await tester.pump();
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();

    expect(find.text('Invite to Melt Chat'), findsOneWidget);
  });
}
