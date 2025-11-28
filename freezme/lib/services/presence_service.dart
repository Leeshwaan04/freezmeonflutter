import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class PresenceService {
  PresenceService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _enabled = true;

  PresenceService.disabled()
      : _firestore = null,
        _enabled = false;

  final FirebaseFirestore? _firestore;
  final bool _enabled;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore!.collection('users').doc(uid);

  Future<void> setStatus(String uid, {required String status}) {
    if (!_enabled) return Future<void>.value();
    return _userDoc(uid).set(
      <String, dynamic>{
        'status': status,
        'lastActive': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Stream<String?> watchStatus(String uid) {
    if (!_enabled) return const Stream<String?>.empty();
    return _userDoc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return snapshot.data()?['status'] as String?;
    });
  }
}
