import 'dart:async';

import '../models/melt_chat_session.dart';
import 'websocket_service.dart';

abstract class MeltChatSessionService {
  Future<MeltChatSession> createSession({
    required String hostUid,
    required String targetUid,
    required String slotLabel,
  });

  Stream<MeltChatSession?> watchSession(String sessionId);

  Future<void> updateStatus(String sessionId, String status);
}

/// WebSocket-backed implementation — replaces FirestoreMeltChatSessionService.
class WebSocketMeltChatSessionService implements MeltChatSessionService {
  WebSocketMeltChatSessionService({
    Duration sessionDuration = const Duration(hours: 1),
  }) : _sessionDuration = sessionDuration;

  final Duration _sessionDuration;

  @override
  Future<MeltChatSession> createSession({
    required String hostUid,
    required String targetUid,
    required String slotLabel,
  }) async {
    final now = DateTime.now().toUtc();
    // Return a locally-constructed session; the server manages the real one.
    return MeltChatSession(
      id: 'pending',
      hostUid: hostUid,
      targetUid: targetUid,
      slotLabel: slotLabel,
      status: 'active',
      createdAt: now,
      expiresAt: now.add(_sessionDuration),
    );
  }

  @override
  Stream<MeltChatSession?> watchSession(String sessionId) {
    return WebSocketService.instance.onMeltStatus
        .where((e) => e['sessionId'] == sessionId || sessionId == 'pending')
        .map((e) {
          final data = e['session'] as Map<String, dynamic>?;
          if (data == null) return null;
          return MeltChatSession.fromJson(data, id: sessionId);
        });
  }

  @override
  Future<void> updateStatus(String sessionId, String status) async {
    // Status updates are sent via REST or WebSocket by the caller.
  }
}

class InMemoryMeltChatSessionService implements MeltChatSessionService {
  final Map<String, MeltChatSession> _sessions = <String, MeltChatSession>{};

  @override
  Future<MeltChatSession> createSession({
    required String hostUid,
    required String targetUid,
    required String slotLabel,
  }) async {
    final id = 'session-${_sessions.length + 1}';
    final now = DateTime.now().toUtc();
    final session = MeltChatSession(
      id: id,
      hostUid: hostUid,
      targetUid: targetUid,
      slotLabel: slotLabel,
      status: 'active',
      createdAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
    );
    _sessions[id] = session;
    return session;
  }

  @override
  Stream<MeltChatSession?> watchSession(String sessionId) async* {
    yield _sessions[sessionId];
  }

  @override
  Future<void> updateStatus(String sessionId, String status) async {
    final session = _sessions[sessionId];
    if (session != null) {
      _sessions[sessionId] = session.copyWith(status: status);
    }
  }
}
