class PathsPresence {
  PathsPresence({
    required this.uid,
    required this.intents,
    required this.radiusKm,
    required this.visibleUntil,
    this.lat,
    this.lng,
    this.geohash,
    this.lastActiveAt,
    this.availability,
    this.interestsSummary,
    this.displayName,
    this.imageUrl,
  });

  final String uid;
  final List<String> intents;
  final double radiusKm;
  final DateTime visibleUntil;
  final double? lat;
  final double? lng;
  final String? geohash;
  final DateTime? lastActiveAt;
  final String? availability;
  final String? interestsSummary;
  final String? displayName;
  final String? imageUrl;

  Map<String, dynamic> toJson() {
    return {
      'userId': uid,
      'intents': intents,
      'radius_km': radiusKm,
      'visible_until': visibleUntil.toIso8601String(),
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (geohash != null) 'geohash': geohash,
      if (lastActiveAt != null) 'last_active_at': lastActiveAt!.toIso8601String(),
      if (availability != null) 'availability': availability,
      if (interestsSummary != null) 'interests': interestsSummary,
      if (displayName != null) 'display_name': displayName,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }

  static PathsPresence fromJson(Map<String, dynamic> json, {String? documentId}) {
    return PathsPresence(
      uid: json['userId'] as String? ?? documentId ?? '',
      intents: (json['intents'] as List<dynamic>? ?? []).cast<String>(),
      radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 0,
      visibleUntil: _parseDateTime(json['visible_until']),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      geohash: json['geohash'] as String?,
      lastActiveAt: json['last_active_at'] != null
          ? _parseDateTimeNullable(json['last_active_at'])
          : null,
      availability: json['availability'] as String?,
      interestsSummary: json['interests'] as String?,
      displayName: json['display_name'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
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

class PathsInvite {
  PathsInvite({
    required this.id,
    required this.senderUid,
    required this.receiverUid,
    required this.intent,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  final String id;
  final String senderUid;
  final String receiverUid;
  final String intent;
  final String status; // pending/accepted/declined/expired/cancelled
  final DateTime createdAt;
  final DateTime? respondedAt;

  Map<String, dynamic> toJson() {
    return {
      'sender_uid': senderUid,
      'receiver_uid': receiverUid,
      'intent': intent,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      if (respondedAt != null) 'responded_at': respondedAt!.toIso8601String(),
    };
  }

  static PathsInvite fromJson(Map<String, dynamic> json, {String? documentId}) {
    return PathsInvite(
      id: documentId ?? json['id'] as String? ?? '',
      senderUid: json['sender_uid'] as String,
      receiverUid: json['receiver_uid'] as String,
      intent: json['intent'] as String,
      status: json['status'] as String,
      createdAt: _parseDateTime(json['created_at']),
      respondedAt: json['responded_at'] != null
          ? _parseDateTimeNullable(json['responded_at'])
          : null,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
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
