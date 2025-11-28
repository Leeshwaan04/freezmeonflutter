import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vibe_profile.dart';
import 'freezme_repository.dart';

/// Fetches data from Cloud Firestore.
///
/// Expects a collection named `profiles` with documents containing
/// the fields described in [VibeProfile.toJson]. If no documents exist or the
/// request fails, the optional [fallback] repository is used.
class FirestoreFreezmeRepository implements FreezmeRepository {
  FirestoreFreezmeRepository({FreezmeRepository? fallback})
      : _firestore = FirebaseFirestore.instance,
        _fallback = fallback;

  final FirebaseFirestore _firestore;
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
}
