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

    if (_fallback != null) {
      return _fallback.fetchDailyProfiles();
    }
    return const [];
  }
}
