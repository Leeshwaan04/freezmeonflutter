import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/vibe_profile.dart';
import 'freezme_repository.dart';
import '../models/chat_message.dart';
import '../models/paths.dart';
import '../models/blinds.dart';
import '../services/geo_service.dart';

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
      final currentUser = FirebaseAuth.instance.currentUser?.uid;
      if (currentUser == null) return <Map<String, dynamic>>[];

      final snapshot = await _firestore
          .collection('chats')
          .where('members', arrayContains: currentUser)
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          final members = List<String>.from(data['members'] ?? []);
          final otherUserId = members.firstWhere(
            (uid) => uid != currentUser,
            orElse: () => '',
          );

          final memberDisplay = data['memberDisplay'] as Map<String, dynamic>? ?? {};
          final otherUserDisplay = memberDisplay[otherUserId] as Map<String, dynamic>? ?? {};

          final lastMessage = data['lastMessage'] as Map<String, dynamic>? ?? {};
          final unread = data['unread'] as Map<String, dynamic>? ?? {};

          return <String, dynamic>{
            'id': doc.id,
            'chatId': doc.id,
            'name': otherUserDisplay['name'] ?? 'Unknown',
            'otherUserName': otherUserDisplay['name'] ?? 'Unknown',
            'photoUrl': otherUserDisplay['photoUrl'] ?? '',
            'lastMessage': lastMessage['text'] ?? '',
            'lastMessageSenderId': lastMessage['senderId'] ?? '',
            'ts': data['updatedAt'],
            'updatedAt': data['updatedAt'],
            'unread': unread[currentUser] ?? 0,
            'status': lastMessage['status'] ?? 'sent',
            'isGroup': data['isGroup'] ?? false,
          };
        }).toList();
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
  Stream<List<Map<String, dynamic>>> watchMatches() {
    final currentUser = FirebaseAuth.instance.currentUser?.uid;
    if (currentUser == null) {
      return Stream.value(<Map<String, dynamic>>[]);
    }

    return _firestore
        .collection('chats')
        .where('members', arrayContains: currentUser)
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final members = List<String>.from(data['members'] ?? []);
        final otherUserId = members.firstWhere(
          (uid) => uid != currentUser,
          orElse: () => '',
        );

        final memberDisplay = data['memberDisplay'] as Map<String, dynamic>? ?? {};
        final otherUserDisplay = memberDisplay[otherUserId] as Map<String, dynamic>? ?? {};

        final lastMessage = data['lastMessage'] as Map<String, dynamic>? ?? {};
        final unread = data['unread'] as Map<String, dynamic>? ?? {};

        // Format timestamp here to avoid heavy work on UI thread
        final timestamp = data['updatedAt'];
        String timeLabel = '';
        try {
          DateTime? parsed;
          if (timestamp is DateTime) {
            parsed = timestamp;
          } else if (timestamp != null) {
            // Handle Firestore Timestamp
            final dynamic ts = timestamp;
            if (ts.runtimeType.toString().contains('Timestamp')) {
              // Firestore Timestamp has seconds and nanoseconds
              try {
                parsed = (ts as dynamic).toDate() as DateTime?;
              } catch (_) {
                parsed = DateTime.now();
              }
            }
          }
          
          if (parsed != null) {
            final now = DateTime.now();
            if (now.difference(parsed).inDays >= 1) {
              timeLabel = '${parsed.month}/${parsed.day}';
            } else {
              final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
              final minute = parsed.minute.toString().padLeft(2, '0');
              final ampm = parsed.hour >= 12 ? 'PM' : 'AM';
              timeLabel = '$hour:$minute $ampm';
            }
          }
        } catch (_) {
          timeLabel = '';
        }

        return <String, dynamic>{
          'id': doc.id,
          'chatId': doc.id,
          'name': otherUserDisplay['name'] ?? 'Unknown',
          'otherUserName': otherUserDisplay['name'] ?? 'Unknown',
          'photoUrl': otherUserDisplay['photoUrl'] ?? '',
          'lastMessage': lastMessage['text'] ?? '',
          'lastMessageSenderId': lastMessage['senderId'] ?? '',
          'timeLabel': timeLabel, // Pre-formatted time
          'ts': data['updatedAt'],
          'updatedAt': data['updatedAt'],
          'unread': unread[currentUser] ?? 0,
          'status': lastMessage['status'] ?? 'sent',
          'isGroup': data['isGroup'] ?? false,
          'isPinned': (data['pinnedBy'] as List?)?.contains(currentUser) ?? false,
          'isMuted': (data['mutedBy'] as Map?)?.containsKey(currentUser) ?? false,
          'isArchived': (data['archivedBy'] as List?)?.contains(currentUser) ?? false,
          'isTyping': (data['typing'] as Map?)?.entries.any((e) => e.key != currentUser && (e.value['isTyping'] as bool? ?? false)) ?? false,
        };
      }).toList();
    });
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
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? bio,
    int? age,
    String? location,
    List<String>? interests,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (displayName != null) updates['displayName'] = displayName;
      if (bio != null) updates['bio'] = bio;
      if (age != null) updates['age'] = age;
      if (location != null) updates['location'] = location;
      if (interests != null) updates['interests'] = interests;
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('profiles').doc(uid).set(
        updates,
        SetOptions(merge: true),
      );
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) {
        return fallback.updateProfile(
          uid: uid,
          displayName: displayName,
          bio: bio,
          age: age,
          location: location,
          interests: interests,
        );
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
      final batch = _firestore.batch();

      // 1. Add message to subcollection
      final messageRef = _firestore
          .collection('chats')
          .doc(message.chatId)
          .collection('messages')
          .doc();
      batch.set(messageRef, message.toJson());

      // 2. Update chat document with lastMessage and updatedAt
      final chatRef = _firestore.collection('chats').doc(message.chatId);

      // Get other user ID to increment their unread count
      final chatDoc = await chatRef.get();
      if (chatDoc.exists) {
        final data = chatDoc.data()!;
        final members = List<String>.from(data['members'] ?? []);
        final currentUser = FirebaseAuth.instance.currentUser?.uid;
        final otherUserId = members.firstWhere(
          (uid) => uid != currentUser,
          orElse: () => '',
        );

        batch.update(chatRef, {
          'lastMessage': {
            'text': message.text,
            'senderId': message.senderId,
            'status': message.status ?? 'sent',
            'sentAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
          if (otherUserId.isNotEmpty) 'unread.$otherUserId': FieldValue.increment(1),
        });
      }

      await batch.commit();
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.sendMessage(message);
      rethrow;
    }
  }

  @override
  Stream<List<ChatMessage>> messagesForChat(String chatId, {int limit = 50}) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromJson(doc.data(), documentId: doc.id))
            .toList());
  }

  @override
  Future<List<ChatMessage>> loadMoreMessages(
    String chatId, {
    required ChatMessage lastMessage,
    int limit = 50,
  }) async {
    try {
      final lastDoc = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(lastMessage.documentId ?? '')
          .get();

      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .startAfterDocument(lastDoc)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ChatMessage.fromJson(doc.data(), documentId: doc.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> markChatAsRead(String chatId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser?.uid;
      if (currentUser == null) return;

      await _firestore.collection('chats').doc(chatId).update({
        'unread.$currentUser': 0,
      });
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.markChatAsRead(chatId);
      rethrow;
    }
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

  // Chat Management
  @override
  Future<void> deleteChat(String chatId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser?.uid;
      if (currentUser == null) return;

      // Soft delete: Add user to deletedBy array
      await _firestore.collection('chats').doc(chatId).update({
        'deletedBy': FieldValue.arrayUnion([currentUser]),
      });
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.deleteChat(chatId);
      rethrow;
    }
  }

  @override
  Future<void> pinChat(String chatId, bool pin) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser?.uid;
      if (currentUser == null) return;

      final batch = _firestore.batch();
      final settingsRef = _firestore.collection('user_chat_settings').doc(currentUser);
      batch.set(
        settingsRef,
        {
          'pinnedChats': pin
              ? FieldValue.arrayUnion([chatId])
              : FieldValue.arrayRemove([chatId]),
        },
        SetOptions(merge: true),
      );

      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.update(chatRef, {
        'pinnedBy': pin
            ? FieldValue.arrayUnion([currentUser])
            : FieldValue.arrayRemove([currentUser]),
      });

      await batch.commit();
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.pinChat(chatId, pin);
      rethrow;
    }
  }

  @override
  Future<void> muteChat(String chatId, bool mute) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser?.uid;
      if (currentUser == null) return;

      final batch = _firestore.batch();
      final settingsRef = _firestore.collection('user_chat_settings').doc(currentUser);
      final muteUntil = mute ? DateTime.now().add(const Duration(days: 365)) : null;
      
      batch.set(
        settingsRef,
        {
          'mutedChats': {
            chatId: muteUntil,
          },
        },
        SetOptions(merge: true),
      );

      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.update(chatRef, {
        'mutedBy.$currentUser': muteUntil,
      });

      await batch.commit();
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.muteChat(chatId, mute);
      rethrow;
    }
  }

  @override
  Future<void> archiveChat(String chatId, bool archive) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser?.uid;
      if (currentUser == null) return;

      final batch = _firestore.batch();
      final settingsRef = _firestore.collection('user_chat_settings').doc(currentUser);
      batch.set(
        settingsRef,
        {
          'archivedChats': archive
              ? FieldValue.arrayUnion([chatId])
              : FieldValue.arrayRemove([chatId]),
        },
        SetOptions(merge: true),
      );

      final chatRef = _firestore.collection('chats').doc(chatId);
      batch.update(chatRef, {
        'archivedBy': archive
            ? FieldValue.arrayUnion([currentUser])
            : FieldValue.arrayRemove([currentUser]),
      });

      await batch.commit();
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.archiveChat(chatId, archive);
      rethrow;
    }
  }

  @override
  Future<void> updateTypingStatus(String chatId, bool isTyping) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser?.uid;
      if (currentUser == null) return;

      await _firestore.collection('chats').doc(chatId).update({
        'typing.$currentUser': {
          'isTyping': isTyping,
          'startedAt': isTyping ? FieldValue.serverTimestamp() : null,
        }
      });
    } catch (_) {
      final fallback = _fallback;
      if (fallback != null) return fallback.updateTypingStatus(chatId, isTyping);
      rethrow;
    }
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

  // ============================================================================
  // Feed (Social Posts) Implementation
  // ============================================================================

  @override
  Future<String> createPost({
    required List<String> photoUrls,
    String? caption,
    required String visibility,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};

      final postRef = await _firestore.collection('feed_posts').add({
        'authorUid': currentUser.uid,
        'authorName': userData['displayName'] ?? currentUser.displayName ?? 'Anonymous',
        'authorPhotoUrl': userData['photoUrls']?[0] ?? currentUser.photoURL,
        'caption': caption,
        'photoUrls': photoUrls,
        'visibility': visibility,
        'likeCount': 0,
        'commentCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return postRef.id;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchFeed({int limit = 20}) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('feed_posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      final posts = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        final likeDoc = await _firestore
            .collection('post_likes')
            .doc(doc.id)
            .collection('likes')
            .doc(currentUser.uid)
            .get();

        posts.add({
          ...data,
          'id': doc.id,
          'isLikedByMe': likeDoc.exists,
        });
      }

      return posts;
    });
  }

  @override
  Future<List<Map<String, dynamic>>> loadMorePosts({
    required String lastPostId,
    int limit = 20,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return [];

      final lastDoc = await _firestore.collection('feed_posts').doc(lastPostId).get();
      
      final snapshot = await _firestore
          .collection('feed_posts')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastDoc)
          .limit(limit)
          .get();

      final posts = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        
        final likeDoc = await _firestore
            .collection('post_likes')
            .doc(doc.id)
            .collection('likes')
            .doc(currentUser.uid)
            .get();

        posts.add({
          ...data,
          'id': doc.id,
          'isLikedByMe': likeDoc.exists,
        });
      }

      return posts;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final postDoc = await _firestore.collection('feed_posts').doc(postId).get();
      if (!postDoc.exists) throw Exception('Post not found');
      
      final postData = postDoc.data()!;
      if (postData['authorUid'] != currentUser.uid) {
        throw Exception('Not authorized to delete this post');
      }

      await postDoc.reference.delete();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> likePost(String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final batch = _firestore.batch();

      batch.set(
        _firestore.collection('post_likes').doc(postId).collection('likes').doc(currentUser.uid),
        {'likedAt': FieldValue.serverTimestamp()},
      );

      batch.update(
        _firestore.collection('feed_posts').doc(postId),
        {'likeCount': FieldValue.increment(1)},
      );

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> unlikePost(String postId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final batch = _firestore.batch();

      batch.delete(
        _firestore.collection('post_likes').doc(postId).collection('likes').doc(currentUser.uid),
      );

      batch.update(
        _firestore.collection('feed_posts').doc(postId),
        {'likeCount': FieldValue.increment(-1)},
      );

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};

      final batch = _firestore.batch();

      final commentRef = _firestore
          .collection('post_comments')
          .doc(postId)
          .collection('comments')
          .doc();
          
      batch.set(commentRef, {
        'authorUid': currentUser.uid,
        'authorName': userData['displayName'] ?? currentUser.displayName ?? 'Anonymous',
        'authorPhotoUrl': userData['photoUrls']?[0] ?? currentUser.photoURL,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(
        _firestore.collection('feed_posts').doc(postId),
        {'commentCount': FieldValue.increment(1)},
      );

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchComments(String postId) {
    return _firestore
        .collection('post_comments')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          ...doc.data(),
          'id': doc.id,
          'postId': postId,
        };
      }).toList();
    });
  }

  @override
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final commentDoc = await _firestore
          .collection('post_comments')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .get();
          
      if (!commentDoc.exists) throw Exception('Comment not found');
      
      final commentData = commentDoc.data()!;
      if (commentData['authorUid'] != currentUser.uid) {
        throw Exception('Not authorized to delete this comment');
      }

      final batch = _firestore.batch();

      batch.delete(commentDoc.reference);
      
      batch.update(
        _firestore.collection('feed_posts').doc(postId),
        {'commentCount': FieldValue.increment(-1)},
      );

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<VibeProfile>> fetchTonightPool({
    required double lat,
    required double lng,
    required String timezone,
  }) async {
    try {
      final geoService = GeoService();

      // 1. Calculate geohash for user location (precision 5 for ~25km radius)
      final geohash = geoService.encodeGeohash(lat, lng, precision: 5);
      final geohashPrefix = geohash.substring(0, 4); // ~40km radius for broader search

      // 2. Calculate timezone offset to determine local 6 PM
      final now = DateTime.now();
      tz.Location userTimezone;
      try {
        userTimezone = tz.getLocation(timezone);
      } catch (_) {
        // Fallback to UTC if timezone is invalid
        userTimezone = tz.UTC;
      }

      final userNow = tz.TZDateTime.from(now, userTimezone);
      final last6PM = tz.TZDateTime(userTimezone, userNow.year, userNow.month, userNow.day, 18);

      // If current time is before 6 PM today, use yesterday's 6 PM
      final cutoffTime = userNow.hour < 18 ? last6PM.subtract(const Duration(days: 1)) : last6PM;

      // 3. Query Firestore with geo + time constraints
      final snapshot = await _firestore
          .collection('profiles')
          .where('geohash', isGreaterThanOrEqualTo: geohashPrefix)
          .where('geohash', isLessThan: '$geohashPrefix\uf8ff')
          .where('lastActive', isGreaterThan: cutoffTime.toUtc().toIso8601String())
          .orderBy('geohash')
          .orderBy('lastActive', descending: true)
          .limit(100)
          .get();

      // 4. Filter by distance client-side (Firestore can't do geo + time in one query)
      final profiles = snapshot.docs
          .map((doc) => VibeProfile.fromJson(doc.data(), documentId: doc.id))
          .where((profile) {
            // Check if profile has location data
            if (profile.lat == null || profile.lng == null) return false;
            final distance = geoService.distanceBetween(lat, lng, profile.lat!, profile.lng!);
            return distance <= 50; // 50km radius
          })
          .toList();

      // 5. Sort by recency + proximity (Tonight Algorithm)
      profiles.sort((a, b) {
        final aScore = _calculateTonightScore(a, lat, lng, userNow, geoService);
        final bScore = _calculateTonightScore(b, lat, lng, userNow, geoService);
        return bScore.compareTo(aScore);
      });

      return profiles.take(50).toList();
    } catch (e) {
      // fall through to fallback
    }

    final fallback = _fallback;
    if (fallback != null) {
      return fallback.fetchTonightPool(lat: lat, lng: lng, timezone: timezone);
    }
    return const [];
  }

  /// Calculate Tonight score: 60% recency + 40% proximity
  double _calculateTonightScore(
    VibeProfile profile,
    double userLat,
    double userLng,
    tz.TZDateTime now,
    GeoService geoService,
  ) {
    // Recency score (0-100): Active in last hour = 100, 24 hours ago = 0
    final lastActive = profile.lastActive ?? now.subtract(const Duration(days: 1));
    final hoursSinceActive = now.difference(lastActive).inHours;
    final recencyScore = (100 - (hoursSinceActive * 4)).clamp(0.0, 100.0);

    // Proximity score (0-100): 0km = 100, 50km = 0
    double proximityScore = 0;
    if (profile.lat != null && profile.lng != null) {
      final distance = geoService.distanceBetween(userLat, userLng, profile.lat!, profile.lng!);
      proximityScore = (100 - (distance * 2)).clamp(0.0, 100.0);
    }

    // Weighted average: 60% recency, 40% proximity
    return (recencyScore * 0.6) + (proximityScore * 0.4);
  }

  @override
  Future<void> updateUserPreferences({
    required int ageMin,
    required int ageMax,
    required double distanceKm,
    required String bio,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set({
      'preferences': {
        'ageMin': ageMin,
        'ageMax': ageMax,
        'distanceKm': distanceKm,
      },
      'bio': bio,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<Map<String, dynamic>> fetchUserPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final prefs = data['preferences'] as Map<String, dynamic>? ?? {};
        // Add bio if it's there
        if (data.containsKey('bio')) prefs['bio'] = data['bio'];
        if (data.containsKey('interests')) prefs['intents'] = data['interests']; // Mapping 'interests' to intents logic for now
        
        return prefs;
      }
    } catch (_) {
      // Fallback or empty
    }
    
    // Fallback defaults
    return {
      'ageMin': 18,
      'ageMax': 35,
      'distanceKm': 10.0,
    };
  }
}
