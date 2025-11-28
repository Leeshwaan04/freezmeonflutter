import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.senderUid,
    required this.text,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String sessionId;
  final String senderUid;
  final String text;
  final String status;
  final DateTime createdAt;

  ChatMessage copyWith({String? status}) => ChatMessage(
    id: id,
    sessionId: sessionId,
    senderUid: senderUid,
    text: text,
    status: status ?? this.status,
    createdAt: createdAt,
  );

  static ChatMessage fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      sessionId: doc.reference.parent.parent?.id ?? 'unknown',
      senderUid: data['senderUid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      status: data['status'] as String? ?? 'sent',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'senderUid': senderUid,
    'text': text,
    'status': status,
    'createdAt': createdAt,
  };
}

class ChatMessageService {
  ChatMessageService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _messages(String sessionId) =>
      _firestore.collection('chats').doc(sessionId).collection('messages');

  Future<void> sendMessage({
    required String sessionId,
    required String senderUid,
    required String text,
  }) {
    return _messages(sessionId).add(<String, dynamic>{
      'senderUid': senderUid,
      'text': text,
      'status': 'sent',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ChatMessage>> watchMessages(String sessionId) {
    return _messages(sessionId)
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(ChatMessage.fromDoc).toList(growable: false),
        );
  }

  Future<void> updateStatus({
    required String sessionId,
    required String messageId,
    required String status,
  }) {
    return _messages(
      sessionId,
    ).doc(messageId).update(<String, dynamic>{'status': status});
  }
}
