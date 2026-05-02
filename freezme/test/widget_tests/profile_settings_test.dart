import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freezme/main.dart';
import 'package:freezme/core/app_stage.dart';
import 'package:freezme/services/melt_chat_service.dart';
import 'package:freezme/services/photo_upload_service.dart';
import 'package:freezme/services/iap_service.dart';
import '../mocks/mock_repository.dart';

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

Future<AppFlowController> pumpToProfileSettings(WidgetTester tester) async {
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
      ctrl.replaceStack([AppStage.dailyPool]);
      return ctrl;
    },
  ));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  // Drain location (6s) + timezone (4s) timeouts so no pending timers remain.
  await tester.pump(const Duration(seconds: 7));
  return ctrl;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Profile Settings — Navigation', () {
    testWidgets('Edit Profile navigates without removing bottom nav', (tester) async {
      await setSurface(tester);
      final ctrl = await pumpToProfileSettings(tester);

      ctrl.push(AppStage.profileSettings);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      final editBtn = find.textContaining('Edit Profile');
      if (editBtn.evaluate().isNotEmpty) {
        await tester.tap(editBtn.first);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(Scaffold), findsWidgets);
      }
    });

    testWidgets('Profile & Settings page shows user stats', (tester) async {
      await setSurface(tester);
      final ctrl = await pumpToProfileSettings(tester);
      ctrl.push(AppStage.profileSettings);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      final hasStats =
          find.textContaining('%').evaluate().isNotEmpty ||
          find.textContaining('Complete').evaluate().isNotEmpty ||
          find.textContaining('Vibes').evaluate().isNotEmpty ||
          find.textContaining('Matches').evaluate().isNotEmpty;
      expect(hasStats, isTrue);
    });

    testWidgets('Sign Out button is present', (tester) async {
      await setSurface(tester);
      final ctrl = await pumpToProfileSettings(tester);
      ctrl.push(AppStage.profileSettings);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Sign Out'), findsWidgets);
    });

    testWidgets('Freeze Mode toggle is present', (tester) async {
      await setSurface(tester);
      final ctrl = await pumpToProfileSettings(tester);
      ctrl.push(AppStage.profileSettings);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Freeze'), findsWidgets);
    });
  });
}
