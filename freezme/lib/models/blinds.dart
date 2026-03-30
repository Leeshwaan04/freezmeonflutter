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
        'available_until': availableUntil!.toIso8601String(),
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  static BlindQueueEntry fromJson(Map<String, dynamic> json, {String? documentId}) {
    return BlindQueueEntry(
      userId: documentId ?? json['userId'] as String? ?? '',
      intent: json['intent'] as String,
      distanceBucket: json['distance_bucket'] as String,
      interests: (json['interests'] as List<dynamic>?)?.cast<String>(),
      availableUntil: _parseDateTimeNullable(json['available_until']),
      createdAt: _parseDateTimeNullable(json['created_at']),
    );
  }

  static DateTime? _parseDateTimeNullable(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
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
      'expires_at': expiresAt.toIso8601String(),
      'reveal_a': revealA,
      'reveal_b': revealB,
      'reported': reported,
      if (reportReason != null) 'report_reason': reportReason,
    };
  }

  static BlindSession fromJson(Map<String, dynamic> json, {String? documentId}) {
    return BlindSession(
      id: documentId ?? json['id'] as String? ?? '',
      userA: json['user_a'] as String,
      userB: json['user_b'] as String,
      phase: json['phase'] as String,
      expiresAt: _parseDateTime(json['expires_at']),
      revealA: json['reveal_a'] as bool? ?? false,
      revealB: json['reveal_b'] as bool? ?? false,
      reported: json['reported'] as bool? ?? false,
      reportReason: json['report_reason'] as String?,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
