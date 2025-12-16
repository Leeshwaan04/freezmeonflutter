import 'package:flutter/material.dart';
import '../models/blinds.dart';
import '../models/chat_message.dart';
import '../models/paths.dart';
import '../models/vibe_profile.dart';
import 'freezme_repository.dart';

/// Local-only repository that provides deterministic data for demos and tests.
class MockFreezmeRepository implements FreezmeRepository {
  const MockFreezmeRepository();

  @override
  Future<List<VibeProfile>> fetchDailyProfiles() async => _profiles;

  @override
  Future<List<VibeProfile>> fetchTonightPool({
    required double lat,
    required double lng,
    required String timezone,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));
    // Return all profiles for now (simulating they are active tonight)
    return _profiles;
  }

  @override
  Future<void> updateUserPreferences({
    required int ageMin,
    required int ageMax,
    required double distanceKm,
    required String bio,
  }) async {
    // Mock implementation: do nothing or print
    debugPrint('Mock: Updated preferences: age $ageMin-$ageMax, dist $distanceKm, bio $bio');
  }

  @override
  Future<Map<String, dynamic>> fetchUserPreferences() async {
    return {
      'ageMin': 18,
      'ageMax': 35,
      'distanceKm': 10.0,
      'intents': ['Friends', 'Dates'],
    };
  }


  @override
  Future<void> createProfile(VibeProfile profile) async {}

  @override
  Future<void> likeProfile(String targetUid) async {}

  @override
  Future<void> skipProfile(String targetUid) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchMatches() async => const [];

  @override
  Stream<List<Map<String, dynamic>>> watchMatches() {
    final now = DateTime.now();
    final mockChats = [
      {
        'id': 'chat_1',
        'chatId': 'chat_1',
        'name': 'Emma',
        'otherUserName': 'Emma',
        'photoUrl': 'https://i.pravatar.cc/150?img=1',
        'lastMessage': 'Hey! How was your day? 😊',
        'lastMessageSenderId': 'user_2',
        'timeLabel': '2:45 PM',
        'ts': now.subtract(const Duration(hours: 2)),
        'updatedAt': now.subtract(const Duration(hours: 2)),
        'unread': 2,
        'status': 'delivered',
        'isGroup': false,
        'isPinned': true,
        'isMuted': false,
        'isArchived': false,
        'isTyping': false,
        'isOnline': true,
      },
      {
        'id': 'chat_2',
        'chatId': 'chat_2',
        'name': 'Sophie',
        'otherUserName': 'Sophie',
        'photoUrl': 'https://i.pravatar.cc/150?img=2',
        'lastMessage': 'Would love to grab coffee sometime!',
        'lastMessageSenderId': 'user_3',
        'timeLabel': '10:30 AM',
        'ts': now.subtract(const Duration(hours: 6)),
        'updatedAt': now.subtract(const Duration(hours: 6)),
        'unread': 0,
        'status': 'read',
        'isGroup': false,
        'isPinned': false,
        'isMuted': false,
        'isArchived': false,
        'isTyping': false,
        'isOnline': false,
      },
      {
        'id': 'chat_3',
        'chatId': 'chat_3',
        'name': 'Jessica',
        'otherUserName': 'Jessica',
        'photoUrl': 'https://i.pravatar.cc/150?img=3',
        'lastMessage': 'That sounds amazing! 🎬',
        'lastMessageSenderId': 'current_user',
        'timeLabel': '5:15 PM',
        'ts': now.subtract(const Duration(minutes: 45)),
        'updatedAt': now.subtract(const Duration(minutes: 45)),
        'unread': 0,
        'status': 'delivered',
        'isGroup': false,
        'isPinned': false,
        'isMuted': false,
        'isArchived': false,
        'isTyping': false,
        'isOnline': true,
      },
      {
        'id': 'chat_4',
        'chatId': 'chat_4',
        'name': 'Olivia',
        'otherUserName': 'Olivia',
        'photoUrl': 'https://i.pravatar.cc/150?img=4',
        'lastMessage': 'Haha, that\'s hilarious! 😂',
        'lastMessageSenderId': 'user_5',
        'timeLabel': '3:20 PM',
        'ts': now.subtract(const Duration(hours: 3)),
        'updatedAt': now.subtract(const Duration(hours: 3)),
        'unread': 1,
        'status': 'sent',
        'isGroup': false,
        'isPinned': false,
        'isMuted': false,
        'isArchived': false,
        'isTyping': false,
        'isOnline': false,
      },
      {
        'id': 'chat_5',
        'chatId': 'chat_5',
        'name': 'Lily',
        'otherUserName': 'Lily',
        'photoUrl': 'https://i.pravatar.cc/150?img=5',
        'lastMessage': 'Let me know when you\'re free!',
        'lastMessageSenderId': 'user_6',
        'timeLabel': '11/15',
        'ts': now.subtract(const Duration(days: 2)),
        'updatedAt': now.subtract(const Duration(days: 2)),
        'unread': 0,
        'status': 'read',
        'isGroup': false,
        'isPinned': false,
        'isMuted': false,
        'isArchived': false,
        'isTyping': false,
        'isOnline': false,
      },
    ];
    return Stream.value(mockChats);
  }

  @override
  Future<void> updateProfilePhotos({
    required String uid,
    required List<String> photoUrls,
  }) async {}

  @override
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? bio,
    int? age,
    String? location,
    List<String>? interests,
  }) async {}

  @override
  Future<VibeProfile?> fetchProfile(String uid) async =>
      _profiles.firstWhere((p) => p.uid == uid, orElse: () => _profiles.first);

  // Messaging (no-op)
  @override
  Future<void> sendMessage(ChatMessage message) async {}
  @override
  Stream<List<ChatMessage>> messagesForChat(String chatId, {int limit = 50}) =>
      const Stream.empty();
  @override
  Future<List<ChatMessage>> loadMoreMessages(
    String chatId, {
    required ChatMessage lastMessage,
    int limit = 50,
  }) async => [];
  @override
  Future<void> markChatAsRead(String chatId) async {}
  @override
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {}
  @override
  Future<void> signOut() async {}

  // Chat Management
  @override
  Future<void> deleteChat(String chatId) async {}
  @override
  Future<void> pinChat(String chatId, bool pin) async {}
  @override
  Future<void> muteChat(String chatId, bool mute) async {}
  @override
  Future<void> archiveChat(String chatId, bool archive) async {}
  @override
  Future<void> updateTypingStatus(String chatId, bool isTyping) async {}

  // Paths
  @override
  Future<void> upsertPathsPresence(PathsPresence presence) async {}
  @override
  Stream<List<PathsPresence>> fetchNearbyPaths({
    required double radiusKm,
    required Set<String> intents,
    double? lat,
    double? lng,
  }) =>
      Stream.value(const []);
  @override
  Future<String> sendPathsInvite({
    required String receiverUid,
    required String intent,
  }) async =>
      'mock';
  @override
  Stream<PathsInvite> inviteStatus(String inviteId) => const Stream.empty();
  @override
  Future<void> cancelPathsInvite(String inviteId) async {}

  // Blinds
  @override
  Future<void> enqueueBlind(BlindQueueEntry entry) async {}
  @override
  Future<void> dequeueBlind(String userId) async {}
  @override
  Future<void> createBlindSession(BlindSession session) async {}
  @override
  Stream<BlindSession> blindSessionUpdates(String sessionId) =>
      const Stream.empty();
  @override
  Future<void> reportBlindSession(String sessionId, String reason) async {}

  static const List<VibeProfile> _profiles = [
    VibeProfile(
      uid: 'mock-priya',
      id: 1,
      name: 'Priya',
      age: 24,
      imageUrl:
          'https://images.unsplash.com/photo-1546961329-78bef0414d7c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx5b3VuZyUyMHdvbWFuJTIwcG9ydHJhaXR8ZW58MXx8fHwxNzYwOTQ2MDQ5fDA&ixlib=rb-4.1.0&q=80&w=1080',
      photoUrls: <String>[
        'https://images.unsplash.com/photo-1546961329-78bef0414d7c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx5b3VuZyUyMHdvbWFuJTIwcG9ydHJhaXR8ZW58MXx8fHwxNzYwOTQ2MDQ5fDA&ixlib=rb-4.1.0&q=80&w=1080',
      ],
      compatibility: 92,
      bio:
          'Adventure seeker | Coffee addict | Let\'s explore the city together ☕',
      distance: '2 km away',
    ),
    VibeProfile(
      uid: 'mock-alex',
      id: 2,
      name: 'Alex',
      age: 27,
      imageUrl:
          'https://images.unsplash.com/flagged/photo-1596479042555-9265a7fa7983?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx5b3VuZyUyMG1hbiUyMHBvcnRyYWl0fGVufDF8fHx8MTc2MDkzNjI2MHww&ixlib=rb-4.1.0&q=80&w=1080',
      photoUrls: <String>[
        'https://images.unsplash.com/flagged/photo-1596479042555-9265a7fa7983?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx5b3VuZyUyMG1hbiUyMHBvcnRyYWl0fGVufDF8fHx8MTc2MDkzNjI2MHww&ixlib=rb-4.1.0&q=80&w=1080',
      ],
      compatibility: 88,
      bio:
          'Fitness enthusiast | Foodie | Looking for meaningful connections 💪',
      distance: '5 km away',
    ),
    VibeProfile(
      uid: 'mock-sophie',
      id: 3,
      name: 'Sophie',
      age: 26,
      imageUrl:
          'https://images.unsplash.com/photo-1591969851586-adbbd4accf81?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxyb21hbnRpYyUyMGNvdXBsZXxlbnwxfHx8fDE3NjA5Nzg1Nzh8MA&ixlib=rb-4.1.0&q=80&w=1080',
      photoUrls: <String>[
        'https://images.unsplash.com/photo-1591969851586-adbbd4accf81?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxyb21hbnRpYyUyMGNvdXBsZXxlbnwxfHx8fDE3NjA5Nzg1Nzh8MA&ixlib=rb-4.1.0&q=80&w=1080',
      ],
      compatibility: 85,
      bio:
          'Artist at heart | Music lover | Deep conversations over small talk 🎨',
      distance: '3 km away',
    ),
  ];

  // Feed (Social Posts) - Mock implementations
  @override
  Future<String> createPost({
    required List<String> photoUrls,
    String? caption,
    required String visibility,
  }) async => 'mock-post-id';

  @override
  Stream<List<Map<String, dynamic>>> watchFeed({int limit = 20}) =>
      Stream.value(const []);

  @override
  Future<List<Map<String, dynamic>>> loadMorePosts({
    required String lastPostId,
    int limit = 20,
  }) async => [];

  @override
  Future<void> deletePost(String postId) async {}

  @override
  Future<void> likePost(String postId) async {}

  @override
  Future<void> unlikePost(String postId) async {}

  @override
  Future<void> addComment({
    required String postId,
    required String text,
  }) async {}

  @override
  Stream<List<Map<String, dynamic>>> watchComments(String postId) =>
      Stream.value(const []);

  @override
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {}
}
