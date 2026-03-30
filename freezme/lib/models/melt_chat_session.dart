class MeltChatSession {
  const MeltChatSession({
    required this.id,
    required this.hostUid,
    required this.targetUid,
    required this.slotLabel,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String hostUid;
  final String targetUid;
  final String slotLabel;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  MeltChatSession copyWith({String? status, DateTime? expiresAt}) {
    return MeltChatSession(
      id: id,
      hostUid: hostUid,
      targetUid: targetUid,
      slotLabel: slotLabel,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt,
    );
  }

  static MeltChatSession fromJson(Map<String, dynamic> json, {String? id}) {
    return MeltChatSession(
      id: id ?? json['id'] as String? ?? '',
      hostUid: json['hostUid'] as String? ?? 'unknown',
      targetUid: json['targetUid'] as String? ?? 'unknown',
      slotLabel: json['slotLabel'] as String? ?? 'Tonight',
      status: json['status'] as String? ?? 'active',
      createdAt: _parseDateTime(json['createdAt']),
      expiresAt: _parseDateTime(json['expiresAt']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'hostUid': hostUid,
    'targetUid': targetUid,
    'slotLabel': slotLabel,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
