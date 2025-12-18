import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freezme/main.dart';
import 'package:freezme/models/vibe_profile.dart'; // Added
import 'package:freezme/services/melt_chat_service.dart';
import 'package:freezme/services/photo_upload_service.dart';
import 'package:freezme/services/iap_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';
import 'mocks/fake_freezme_repository.dart';

class _FakePhotoUploadService implements PhotoUploadService {
  _FakePhotoUploadService(this.url);

  final String url;
  int calls = 0;

  @override
  Future<UploadedPhoto> pickAndUpload({required int slotIndex}) async {
    calls++;
    return UploadedPhoto(url: '$url-$slotIndex');
  }

  @override
  Future<String> uploadPhoto(File file, {required String userId, required int photoIndex}) async {
    // Simulate upload by returning a dummy URL.
    return '$url-$photoIndex';
  }
}

class _FailingPhotoUploadService implements PhotoUploadService {
  @override
  Future<UploadedPhoto> pickAndUpload({required int slotIndex}) async {
    throw const PhotoUploadException('failure');
  }

  @override
  Future<String> uploadPhoto(File file, {required String userId, required int photoIndex}) async {
    throw const PhotoUploadException('failure');
  }
}

class _RecordingMeltChatService implements MeltChatService {
  final List<Map<String, String>> invites = <Map<String, String>>[];

  @override
  Future<void> sendInvite({
    required String targetUid,
    required String slotLabel,
  }) async {
    invites.add(<String, String>{'uid': targetUid, 'slot': slotLabel});
  }

  @override
  Future<void> respondInvite({required String inviteId, required String action}) async {}
}

class _FailingMeltChatService implements MeltChatService {
  @override
  Future<void> sendInvite({
    required String targetUid,
    required String slotLabel,
  }) async {
    throw const MeltChatException('network');
  }

  @override
  Future<void> respondInvite({required String inviteId, required String action}) async {}
}

VibeProfile _profile() => const VibeProfile(
  uid: 'test_uid',
  id: 42,
  name: 'Test',
  age: 25,
  imageUrl: 'https://example.com/photo.jpg',
  compatibility: 90,
  bio: 'Tester',
  distance: '1 km away',
);

class _FakeIAPService extends ChangeNotifier implements IAPService {
  @override
  List<ProductDetails> get products => [];
  
  @override 
  bool get isAvailable => true;
  
  @override
  bool get purchasePending => false;
  
  @override
  String? get error => null;
  
  @override
  Future<void> buy(ProductDetails product) async {}
  
  @override
  Future<void> restorePurchases() async {}
  
  @override
  ProductDetails? get weeklyPlan => null;
  
  @override
  ProductDetails? get monthlyPlan => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Photo slots', () {
    test('successful upload updates slot state', () async {
      final uploader = _FakePhotoUploadService('mock');
      final controller = AppFlowController.test(
        photoUploadService: uploader,
        repository: FakeFreezmeRepository(),
        iapService: _FakeIAPService(),
        meltChatService: _RecordingMeltChatService(),
      );

      await controller.uploadPhotoForSlot(0);

      expect(controller.photoSlots.first.status, PhotoSlotStatus.uploaded);
      expect(controller.photoSlots.first.imageUrl, 'mock-0');
      expect(uploader.calls, 1);
    });

    test('failed upload marks slot failed', () async {
      final controller = AppFlowController.test(
        photoUploadService: _FailingPhotoUploadService(),
        repository: FakeFreezmeRepository(),
        iapService: _FakeIAPService(),
        meltChatService: _RecordingMeltChatService(),
      );

      await expectLater(
        controller.uploadPhotoForSlot(0),
        throwsA(isA<PhotoUploadException>()),
      );

      expect(controller.photoSlots.first.status, PhotoSlotStatus.failed);
    });
  });

  group('Melt Chat invites', () {
    test('sendMeltChatInvite delegates to service', () async {
      final service = _RecordingMeltChatService();
      final controller = AppFlowController.test(
        photoUploadService: _FakePhotoUploadService('mock'),
        meltChatService: service,
        repository: FakeFreezmeRepository(),
        iapService: _FakeIAPService(),
      );

      final result = await controller.sendMeltChatInvite(
        _profile(),
        'Tonight 9 PM',
      );

      expect(result, isTrue);
      expect(service.invites, [
        {'uid': 'test_uid', 'slot': 'Tonight 9 PM'},
      ]);
    });

    test('sendMeltChatInvite returns false when service throws', () async {
      final controller = AppFlowController.test(
        photoUploadService: _FakePhotoUploadService('mock'),
        meltChatService: _FailingMeltChatService(),
        repository: FakeFreezmeRepository(),
        iapService: _FakeIAPService(),
      );

      final result = await controller.sendMeltChatInvite(_profile(), 'Tonight');

      expect(result, isFalse);
    });
  });
}
