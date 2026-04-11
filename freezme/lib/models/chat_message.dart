class ChatMessage {
  ChatMessage({
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.documentId,
    this.status,
    this.clientMsgId,
    this.deliveredAt,
    this.readAt,
  });

  final String chatId;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final String? documentId;
  final String? status;      // sent/delivered/read
  final String? clientMsgId; // local UUID for dedup
  final DateTime? deliveredAt;
  final DateTime? readAt;

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'sentAt': sentAt.toIso8601String(),
      if (status != null) 'status': status,
      if (clientMsgId != null) 'clientMsgId': clientMsgId,
    };
  }

  static ChatMessage fromJson(Map<String, dynamic> json, {String? documentId}) {
    return ChatMessage(
      chatId: json['chatId'] as String? ?? '',
      // Server sends 'senderUid'; older paths may send 'senderId'
      senderId: (json['senderUid'] ?? json['senderId']) as String? ?? '',
      text: json['text'] as String? ?? '',
      // Server sends 'createdAt'; older paths may send 'sentAt'
      sentAt: _parseDateTime(json['createdAt'] ?? json['sentAt']),
      documentId: documentId ?? json['id'] as String?,
      status: json['status'] as String?,
      clientMsgId: json['clientMsgId'] as String?,
      deliveredAt: _parseDateTimeNullable(json['deliveredAt']),
      readAt: _parseDateTimeNullable(json['readAt']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) return DateTime.parse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static DateTime? _parseDateTimeNullable(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
