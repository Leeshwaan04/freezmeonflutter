import 'package:flutter_test/flutter_test.dart';

import 'package:freezme/main.dart';
import 'package:freezme/services/melt_chat_service.dart';
import 'package:freezme/services/photo_upload_service.dart';

class _FakePhotoUploadService implements PhotoUploadService {
  _FakePhotoUploadService(this.url);

  final String url;
  int calls = 0;

  @override
  Future<UploadedPhoto> pickAndUpload({required int slotIndex}) async {
    calls++;
    return UploadedPhoto(url: '$url-$slotIndex');
  }
}

class _FailingPhotoUploadService implements PhotoUploadService {
  @override
  Future<UploadedPhoto> pickAndUpload({required int slotIndex}) async {
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
}

class _FailingMeltChatService implements MeltChatService {
  @override
  Future<void> sendInvite({
    required String targetUid,
    required String slotLabel,
  }) async {
    throw const MeltChatException('network');
  }
}

VibeProfile _profile() => const VibeProfile(
  id: 42,
  name: 'Test',
  age: 25,
  imageUrl: 'https://example.com/photo.jpg',
  compatibility: 90,
  bio: 'Tester',
  distance: '1 km away',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Photo slots', () {
    test('successful upload updates slot state', () async {
      final uploader = _FakePhotoUploadService('mock');
      final controller = AppFlowController.test(photoUploadService: uploader);

      await controller.uploadPhotoForSlot(0);

      expect(controller.photoSlots.first.status, PhotoSlotStatus.uploaded);
      expect(controller.photoSlots.first.imageUrl, 'mock-0');
      expect(uploader.calls, 1);
    });

    test('failed upload marks slot failed', () async {
      final controller = AppFlowController.test(
        photoUploadService: _FailingPhotoUploadService(),
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
      );

      final result = await controller.sendMeltChatInvite(
        _profile(),
        'Tonight 9 PM',
      );

      expect(result, isTrue);
      expect(service.invites, [
        {'uid': 'profile_42', 'slot': 'Tonight 9 PM'},
      ]);
    });

    test('sendMeltChatInvite returns false when service throws', () async {
      final controller = AppFlowController.test(
        photoUploadService: _FakePhotoUploadService('mock'),
        meltChatService: _FailingMeltChatService(),
      );

      final result = await controller.sendMeltChatInvite(_profile(), 'Tonight');

      expect(result, isFalse);
    });
  });
}
