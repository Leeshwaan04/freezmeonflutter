import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

abstract class MeltChatService {
  Future<void> sendInvite({
    required String targetUid,
    required String slotLabel,
  });
}

class MeltChatException implements Exception {
  const MeltChatException(this.message);

  final String message;

  @override
  String toString() => 'MeltChatException: $message';
}

class FirebaseMeltChatService implements MeltChatService {
  FirebaseMeltChatService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<void> sendInvite({
    required String targetUid,
    required String slotLabel,
  }) {
    return _functions.httpsCallable('sendMeltChatInvite').call(
      <String, dynamic>{'targetUid': targetUid, 'slot': slotLabel},
    );
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
    if (shouldFail) {
      throw const MeltChatException('mock_failure');
    }
    sentInvites.add(<String, String>{
      'targetUid': targetUid,
      'slot': slotLabel,
    });
  }
}
