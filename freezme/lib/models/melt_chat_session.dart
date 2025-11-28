import 'package:cloud_firestore/cloud_firestore.dart';

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

  static MeltChatSession fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return MeltChatSession(
      id: doc.id,
      hostUid: data['hostUid'] as String? ?? 'unknown',
      targetUid: data['targetUid'] as String? ?? 'unknown',
      slotLabel: data['slotLabel'] as String? ?? 'Tonight',
      status: data['status'] as String? ?? 'active',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt:
          (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'hostUid': hostUid,
    'targetUid': targetUid,
    'slotLabel': slotLabel,
    'status': status,
    'createdAt': Timestamp.fromDate(createdAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
  };
}
