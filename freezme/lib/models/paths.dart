import 'package:cloud_firestore/cloud_firestore.dart';

class PathsPresence {
  PathsPresence({
    required this.userId,
    required this.intents,
    required this.radiusKm,
    required this.visibleUntil,
    this.lat,
    this.lng,
    this.geohash,
    this.lastActiveAt,
    this.availability,
    this.interestsSummary,
  });

  final String userId;
  final List<String> intents;
  final double radiusKm;
  final DateTime visibleUntil;
  final double? lat;
  final double? lng;
  final String? geohash;
  final DateTime? lastActiveAt;
  final String? availability;
  final String? interestsSummary;

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'intents': intents,
      'radius_km': radiusKm,
      'visible_until': Timestamp.fromDate(visibleUntil),
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (geohash != null) 'geohash': geohash,
      if (lastActiveAt != null) 'last_active_at': Timestamp.fromDate(lastActiveAt!),
      if (availability != null) 'availability': availability,
      if (interestsSummary != null) 'interests': interestsSummary,
    };
  }

  static PathsPresence fromJson(Map<String, dynamic> json, {String? documentId}) {
    return PathsPresence(
      userId: json['userId'] ?? documentId ?? '',
      intents: (json['intents'] as List<dynamic>? ?? []).cast<String>(),
      radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 0,
      visibleUntil: (json['visible_until'] as Timestamp).toDate(),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      geohash: json['geohash'] as String?,
      lastActiveAt: (json['last_active_at'] as Timestamp?)?.toDate(),
      availability: json['availability'] as String?,
      interestsSummary: json['interests'] as String?,
    );
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
      'created_at': Timestamp.fromDate(createdAt),
      if (respondedAt != null) 'responded_at': Timestamp.fromDate(respondedAt!),
    };
  }

  static PathsInvite fromJson(Map<String, dynamic> json, {String? documentId}) {
    return PathsInvite(
      id: documentId ?? '',
      senderUid: json['sender_uid'] as String,
      receiverUid: json['receiver_uid'] as String,
      intent: json['intent'] as String,
      status: json['status'] as String,
      createdAt: (json['created_at'] as Timestamp).toDate(),
      respondedAt: (json['responded_at'] as Timestamp?)?.toDate(),
    );
  }
}
