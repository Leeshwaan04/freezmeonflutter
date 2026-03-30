import 'dart:async';

import 'websocket_service.dart';

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

  static ChatMessage fromJson(Map<String, dynamic> data, {String? id, String? sessionId}) {
    return ChatMessage(
      id: id ?? data['id'] as String? ?? '',
      sessionId: sessionId ?? data['sessionId'] as String? ?? 'unknown',
      senderUid: data['senderUid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      status: data['status'] as String? ?? 'sent',
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'senderUid': senderUid,
    'text': text,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class ChatMessageService {
  ChatMessageService();

  /// Returns a stream of messages for [sessionId] bridged from WebSocket events.
  Stream<List<ChatMessage>> watchMessages(String sessionId) {
    final controller = StreamController<List<ChatMessage>>();
    final List<ChatMessage> buffer = [];

    final sub = WebSocketService.instance.chatMessages(sessionId).listen((event) {
      final msgData = event['message'] as Map<String, dynamic>?;
      if (msgData != null) {
        final msg = ChatMessage.fromJson(msgData, sessionId: sessionId);
        buffer.add(msg);
        if (!controller.isClosed) controller.add(List.from(buffer));
      }
    });

    controller.onCancel = sub.cancel;
    return controller.stream;
  }

  /// Send a message via WebSocket.
  Future<void> sendMessage({
    required String sessionId,
    required String senderUid,
    required String text,
  }) async {
    WebSocketService.instance.sendChatMessage(chatId: sessionId, text: text);
  }

  /// Update message status — no-op stub (WebSocket handles read receipts).
  Future<void> updateStatus({
    required String sessionId,
    required String messageId,
    required String status,
  }) async {
    // Handled server-side via WebSocket read receipts
  }
}
