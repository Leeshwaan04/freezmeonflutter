import 'dart:async';
import 'package:isar/isar.dart';

import 'websocket_service.dart';
import '../core/database.dart';
import '../models/isar_chat_message.dart';

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

  /// Returns a stream of messages for [sessionId] bridged from WebSocket events and cached in Isar.
  Stream<List<ChatMessage>> watchMessages(String sessionId) {
    final isar = LocalDatabase.instance;
    final controller = StreamController<List<ChatMessage>>();
    StreamSubscription? wsSub;
    StreamSubscription? isarSub;

    controller.onListen = () async {
      // 1. Initial immediate local cache yield
      final initialLocal = await isar.isarChatMessages
          .filter()
          .chatIdEqualTo(sessionId)
          .sortBySentAt()
          .findAll();

      if (!controller.isClosed) {
        controller.add(initialLocal.map((m) => ChatMessage(
          id: m.documentId ?? m.id.toString(),
          sessionId: m.chatId,
          senderUid: m.senderId,
          text: m.text,
          status: m.status ?? 'sent',
          createdAt: m.sentAt,
        )).toList());
      }

      // 2. Setup WebSocket listener to sink into Isar
      wsSub = WebSocketService.instance.chatMessages(sessionId).listen((event) async {
        final msgData = event['message'] as Map<String, dynamic>?;
        if (msgData != null) {
          final domainMsg = ChatMessage.fromJson(msgData, sessionId: sessionId);
          
          final isarMsg = IsarChatMessage()
            ..chatId = domainMsg.sessionId
            ..senderId = domainMsg.senderUid
            ..text = domainMsg.text
            ..sentAt = domainMsg.createdAt
            ..documentId = domainMsg.id
            ..status = domainMsg.status;

          await isar.writeTxn(() async {
            await isar.isarChatMessages.put(isarMsg);
          });
        }
      });

      // 3. Watch Isar database for changes
      isarSub = isar.isarChatMessages
          .filter()
          .chatIdEqualTo(sessionId)
          .sortBySentAt()
          .watch(fireImmediately: true)
          .listen((records) {
        if (!controller.isClosed) {
          controller.add(records.map((m) => ChatMessage(
            id: m.documentId ?? m.id.toString(),
            sessionId: m.chatId,
            senderUid: m.senderId,
            text: m.text,
            status: m.status ?? 'sent',
            createdAt: m.sentAt,
          )).toList());
        }
      });
    };

    controller.onCancel = () {
      wsSub?.cancel();
      isarSub?.cancel();
    };

    return controller.stream;
  }

  /// Send a message via WebSocket.
  Future<void> sendMessage({
    required String sessionId,
    required String senderUid,
    required String text,
  }) async {
    WebSocketService.instance.sendChatMessage(chatId: sessionId, text: text, clientMsgId: '');
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
