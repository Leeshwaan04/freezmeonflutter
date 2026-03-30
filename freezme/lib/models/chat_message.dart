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
      'sentAt': sentAt.toIso8601String(),
      if (status != null) 'status': status,
    };
  }

  static ChatMessage fromJson(Map<String, dynamic> json, {String? documentId}) {
    return ChatMessage(
      chatId: json['chatId'] as String,
      senderId: json['senderId'] as String,
      text: json['text'] as String,
      sentAt: _parseDateTime(json['sentAt']),
      documentId: documentId,
      status: json['status'] as String?,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
