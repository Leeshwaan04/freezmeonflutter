import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/melt_chat_session.dart';

abstract class MeltChatSessionService {
  Future<MeltChatSession> createSession({
    required String hostUid,
    required String targetUid,
    required String slotLabel,
  });

  Stream<MeltChatSession?> watchSession(String sessionId);

  Future<void> updateStatus(String sessionId, String status);
}

class FirestoreMeltChatSessionService implements MeltChatSessionService {
  FirestoreMeltChatSessionService({
    FirebaseFirestore? firestore,
    Duration sessionDuration = const Duration(hours: 1),
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _sessionDuration = sessionDuration;

  final FirebaseFirestore _firestore;
  final Duration _sessionDuration;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('melt_sessions');

  @override
  Future<MeltChatSession> createSession({
    required String hostUid,
    required String targetUid,
    required String slotLabel,
  }) async {
    final doc = _collection.doc();
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(_sessionDuration);
    await doc.set(<String, dynamic>{
      'hostUid': hostUid,
      'targetUid': targetUid,
      'slotLabel': slotLabel,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
    final snapshot = await doc.get();
    return MeltChatSession.fromDoc(snapshot);
  }

  @override
  Stream<MeltChatSession?> watchSession(String sessionId) {
    return _collection.doc(sessionId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return MeltChatSession.fromDoc(snapshot);
    });
  }

  @override
  Future<void> updateStatus(String sessionId, String status) {
    return _collection
        .doc(sessionId)
        .update(<String, dynamic>{
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .catchError((_) {});
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
