import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  ChatMessage({
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.documentId,
    this.status,
  });

  final String chatId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final String? documentId;
  final String? status; // sent/delivered/read

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'sentAt': Timestamp.fromDate(sentAt),
      if (status != null) 'status': status,
    };
  }

  static ChatMessage fromJson(Map<String, dynamic> json, {String? documentId}) {
    return ChatMessage(
      chatId: json['chatId'] as String,
      senderId: json['senderId'] as String,
      text: json['text'] as String,
      sentAt: (json['sentAt'] as Timestamp).toDate(),
      documentId: documentId,
      status: json['status'] as String?,
    );
  }
}
