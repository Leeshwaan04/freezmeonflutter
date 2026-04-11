import 'dart:async';

import 'api_client.dart';

abstract class MeltChatService {
  Future<void> sendInvite({
    required String targetUid,
    required String slotLabel,
  });
  Future<void> respondInvite({
    required String inviteId,
    required String action, // accept/decline
  });
}

class MeltChatException implements Exception {
  const MeltChatException(this.message);

  final String message;

  @override
  String toString() => 'MeltChatException: $message';
}

/// EC2-backed implementation — replaces FirebaseMeltChatService.
class ApiMeltChatService implements MeltChatService {
  final _client = ApiClient.instance;

  @override
  Future<void> sendInvite({
    required String targetUid,
    required String slotLabel,
  }) async {
    try {
      await _client.dio.post<void>(
        '/melt/invite',
        data: {'targetUid': targetUid, 'slotLabel': slotLabel},
      );
    } catch (e) {
      throw MeltChatException('sendInvite failed: $e');
    }
  }

  @override
  Future<void> respondInvite({
    required String inviteId,
    required String action,
  }) async {
    try {
      // Server expects 'accepted'/'declined', UI passes 'accept'/'decline'
      final status = action == 'accept' ? 'accepted' : 'declined';
      await _client.dio.patch<void>(
        '/melt/invite/$inviteId',
        data: {'status': status},
      );
    } catch (e) {
      throw MeltChatException('respondInvite failed: $e');
    }
  }
}

class MockMeltChatService implements MeltChatService {
  MockMeltChatService({
    this.shouldFail = false,
    this.delay = const Duration(milliseconds: 180),
  });

  final bool shouldFail;
  final Duration delay;

  final List<Map<String, String>> sentInvites = <Map<String, String>>[];

  @override
  Future<void> sendInvite({
    required String targetUid,
    required String slotLabel,
  }) async {
    await Future<void>.delayed(delay);
    if (shouldFail) throw const MeltChatException('mock_failure');
    sentInvites.add({'targetUid': targetUid, 'slot': slotLabel});
  }

  @override
  Future<void> respondInvite({
    required String inviteId,
    required String action,
  }) async {
    await Future<void>.delayed(delay);
    if (shouldFail) throw const MeltChatException('mock_failure');
  }
}
