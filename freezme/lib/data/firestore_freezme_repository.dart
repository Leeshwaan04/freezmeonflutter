import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/vibe_profile.dart';
import 'freezme_repository.dart';
import '../models/chat_message.dart';
import '../models/paths.dart';
import '../models/blinds.dart';

/// Fetches data from Cloud Firestore.
///
/// Expects a collection named `profiles` with documents containing
/// the fields described in [VibeProfile.toJson]. If no documents exist or the
/// request fails, the optional [fallback] repository is used.
class FirestoreFreezmeRepository implements FreezmeRepository {
  FirestoreFreezmeRepository({FreezmeRepository? fallback})
      : _firestore = FirebaseFirestore.instance,
        _functions = FirebaseFunctions.instance,
        _fallback = fallback;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FreezmeRepository? _fallback;

  @override
  Future<List<VibeProfile>> fetchDailyProfiles() async {
    try {
      final snapshot = await _firestore
          .collection('profiles')
          .orderBy('id')
          .limit(50)
          .get();

      final docs = snapshot.docs
          .map((doc) => VibeProfile.fromJson(doc.data(), documentId: doc.id))
          .toList();

      if (docs.isNotEmpty) {
        return docs;
      }
    } catch (_) {
      // fall through to fallback
    }

    final fallback = _fallback;
    if (fallback != null) {
      return fallback.fetchDailyProfiles();
    }
    return const <VibeProfile>[];
  }

  @override
  Future<void> createProfile(VibeProfile profile) async {
    try {
      await _firestore
          .collection('profiles')
          .doc(profile.uid)
          .set(profile.toJson(), SetOptions(merge: true));
      return;
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) {
        return fallback.createProfile(profile);
      }
      rethrow;
    }
  }

  @override
  Future<void> likeProfile(String targetUid) async {
    try {
      await _firestore
          .collection('likes')
          .add(<String, dynamic>{'targetUid': targetUid, 'ts': DateTime.now()});
      return;
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) {
        return fallback.likeProfile(targetUid);
      }
      rethrow;
    }
  }

  @override
  Future<void> skipProfile(String targetUid) async {
    try {
      await _firestore
          .collection('skips')
          .add(<String, dynamic>{'targetUid': targetUid, 'ts': DateTime.now()});
      return;
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) {
        return fallback.skipProfile(targetUid);
      }
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMatches() async {
    try {
      final snapshot = await _firestore
          .collection('matches')
          .orderBy('ts', descending: true)
          .limit(50)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
            .toList();
      }
    } catch (_) {
      // fall through
    }
    final fallback = _fallback;
    if (fallback != null) {
      return fallback.fetchMatches();
    }
    return <Map<String, dynamic>>[];
  }

  @override
  Future<void> updateProfilePhotos({
    required String uid,
    required List<String> photoUrls,
  }) async {
    try {
      await _firestore.collection('profiles').doc(uid).set(
        {
          'photoUrls': photoUrls,
          if (photoUrls.isNotEmpty) 'imageUrl': photoUrls.first,
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) {
        return fallback.updateProfilePhotos(uid: uid, photoUrls: photoUrls);
      }
      rethrow;
    }
  }

  @override
  Future<VibeProfile?> fetchProfile(String uid) async {
    try {
      final doc = await _firestore.collection('profiles').doc(uid).get();
      if (doc.exists) {
        return VibeProfile.fromJson(doc.data()!, documentId: doc.id);
      }
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.fetchProfile(uid);
    }
    return null;
  }

  // Messaging
  @override
  Future<void> sendMessage(ChatMessage message) async {
    try {
      await _firestore
          .collection('chats')
          .doc(message.chatId)
          .collection('messages')
          .add(message.toJson());
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.sendMessage(message);
      rethrow;
    }
  }

  @override
  Stream<List<ChatMessage>> messagesForChat(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromJson(doc.data(), documentId: doc.id))
            .toList());
  }

  @override
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await _firestore.collection('presence').doc(userId).set(
        {
          'online': isOnline,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.updateOnlineStatus(userId, isOnline);
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    final fallback = _fallback;
    if (fallback != null) return fallback.signOut();
  }

  // Paths
  @override
  Future<void> upsertPathsPresence(PathsPresence presence) async {
    try {
      await _functions.httpsCallable('upsertPathsPresence').call({
        'intents': presence.intents,
        'radiusKm': presence.radiusKm,
        'visibleUntil': presence.visibleUntil.toIso8601String(),
        'lat': presence.lat,
        'lng': presence.lng,
        'geohash': presence.geohash,
        'availability': presence.availability,
        'interestsSummary': presence.interestsSummary,
      });
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.upsertPathsPresence(presence);
      rethrow;
    }
  }

  @override
  Stream<List<PathsPresence>> fetchNearbyPaths({
    required double radiusKm,
    required Set<String> intents,
    double? lat,
    double? lng,
  }) {
    Future<List<PathsPresence>> load() async {
      try {
        final result = await _functions.httpsCallable('getNearbyPaths').call({
          'radiusKm': radiusKm,
          'intents': intents.toList(),
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        });
        final data = result.data;
        if (data is Map && data['profiles'] is List) {
          return (data['profiles'] as List<dynamic>)
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (m) => PathsPresence.fromJson(
                  m.map((key, value) => MapEntry(key.toString(), value)),
                  documentId: m['id']?.toString(),
                ),
              )
              .toList();
        }
      } catch (_) {
        // fall through to fallback
      }
      final fallback = _fallback;
      if (fallback != null) {
        return fallback.fetchNearbyPaths(
          radiusKm: radiusKm,
          intents: intents,
          lat: lat,
          lng: lng,
        ).first;
      }
      return <PathsPresence>[];
    }

    return Stream.fromFuture(load());
  }

  @override
  Future<String> sendPathsInvite({
    required String receiverUid,
    required String intent,
  }) async {
    try {
      final result = await _functions.httpsCallable('sendPathsInvite').call({
        'receiverUid': receiverUid,
        'intent': intent,
      });
      final data = result.data;
      if (data is Map && data['id'] is String) {
        return data['id'] as String;
      }
      return '';
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) {
        return fallback.sendPathsInvite(
          receiverUid: receiverUid,
          intent: intent,
        );
      }
      rethrow;
    }
  }

  @override
  Stream<PathsInvite> inviteStatus(String inviteId) {
    return _firestore
        .collection('path_invites')
        .doc(inviteId)
        .snapshots()
        .where((doc) => doc.exists)
        .map((doc) => PathsInvite.fromJson(doc.data()!, documentId: doc.id));
  }

  @override
  Future<void> cancelPathsInvite(String inviteId) async {
    try {
      await _functions.httpsCallable('respondPathsInvite').call({
        'inviteId': inviteId,
        'action': 'cancel',
      });
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.cancelPathsInvite(inviteId);
      rethrow;
    }
  }

  // Blinds
  @override
  Future<void> enqueueBlind(BlindQueueEntry entry) async {
    try {
      await _functions.httpsCallable('enqueueBlind').call({
        'intent': entry.intent,
        'distanceBucket': entry.distanceBucket,
        'interests': entry.interests,
        'availableUntil': entry.availableUntil?.toIso8601String(),
      });
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.enqueueBlind(entry);
      rethrow;
    }
  }

  @override
  Future<void> dequeueBlind(String userId) async {
    try {
      await _functions.httpsCallable('dequeueBlind').call();
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.dequeueBlind(userId);
      rethrow;
    }
  }

  @override
  Future<void> createBlindSession(BlindSession session) async {
    try {
      await _functions.httpsCallable('createBlindSession').call({
        'partnerUid': session.userB,
      });
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.createBlindSession(session);
      rethrow;
    }
  }

  @override
  Stream<BlindSession> blindSessionUpdates(String sessionId) {
    return _firestore
        .collection('blinds_sessions')
        .doc(sessionId)
        .snapshots()
        .where((doc) => doc.exists)
        .map((doc) => BlindSession.fromJson(doc.data()!, documentId: doc.id));
  }

  @override
  Future<void> reportBlindSession(String sessionId, String reason) async {
    try {
      await _functions.httpsCallable('reportBlindSession').call({
        'sessionId': sessionId,
        'reason': reason,
      });
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.reportBlindSession(sessionId, reason);
      rethrow;
    }
  }
}
