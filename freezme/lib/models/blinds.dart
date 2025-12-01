import 'package:cloud_firestore/cloud_firestore.dart';

class BlindQueueEntry {
  BlindQueueEntry({
    required this.userId,
    required this.intent,
    required this.distanceBucket,
    this.interests,
    this.availableUntil,
    this.createdAt,
  });

  final String userId;
  final String intent; // friends/dates/either
  final String distanceBucket; // e.g., "0-5km", "5-20km"
  final List<String>? interests;
  final DateTime? availableUntil;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'intent': intent,
      'distance_bucket': distanceBucket,
      if (interests != null) 'interests': interests,
      if (availableUntil != null)
        'available_until': Timestamp.fromDate(availableUntil!),
      'created_at': Timestamp.fromDate(createdAt ?? DateTime.now()),
    };
  }

  static BlindQueueEntry fromJson(Map<String, dynamic> json, {String? documentId}) {
    return BlindQueueEntry(
      userId: documentId ?? '',
      intent: json['intent'] as String,
      distanceBucket: json['distance_bucket'] as String,
      interests: (json['interests'] as List<dynamic>?)?.cast<String>(),
      availableUntil: (json['available_until'] as Timestamp?)?.toDate(),
      createdAt: (json['created_at'] as Timestamp?)?.toDate(),
    );
  }
}

class BlindSession {
  BlindSession({
    required this.id,
    required this.userA,
    required this.userB,
    required this.phase,
    required this.expiresAt,
    this.revealA = false,
    this.revealB = false,
    this.reported = false,
    this.reportReason,
  });

  final String id;
  final String userA;
  final String userB;
  final String phase; // anonymous/reveal
  final DateTime expiresAt;
  final bool revealA;
  final bool revealB;
  final bool reported;
  final String? reportReason;

  Map<String, dynamic> toJson() {
    return {
      'user_a': userA,
      'user_b': userB,
      'phase': phase,
      'expires_at': Timestamp.fromDate(expiresAt),
      'reveal_a': revealA,
      'reveal_b': revealB,
      'reported': reported,
      if (reportReason != null) 'report_reason': reportReason,
    };
  }

  static BlindSession fromJson(Map<String, dynamic> json, {String? documentId}) {
    return BlindSession(
      id: documentId ?? '',
      userA: json['user_a'] as String,
      userB: json['user_b'] as String,
      phase: json['phase'] as String,
      expiresAt: (json['expires_at'] as Timestamp).toDate(),
      revealA: json['reveal_a'] as bool? ?? false,
      revealB: json['reveal_b'] as bool? ?? false,
      reported: json['reported'] as bool? ?? false,
      reportReason: json['report_reason'] as String?,
    );
  }
}
