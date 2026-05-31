import 'package:flutter/material.dart';
import '../models/blinds.dart';
import '../models/chat_message.dart';
import '../models/paths.dart';
import '../models/vibe_profile.dart';
import '../models/blueprint.dart';
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
    await Future.delayed(const Duration(milliseconds: 800));
    return _profiles;
  }

  @override
  Future<void> updateUserPreferences({
    required int ageMin,
    required int ageMax,
    required double distanceKm,
    required String bio,
  }) async {
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
    String? imageUrl,
    String? gender,
    String? location,
    List<String>? interests,
    bool? isPremium,
    bool? allowBlindReveal,
    String? intent,
    List<String>? personalityTraits,
    List<String>? lifestyleFactors,
    String? archetype,
    String? energyType,
    String? paceSignal,
    Map<String, dynamic>? promptAnswer,
    List<Map<String, dynamic>>? presenceWindows,
    List<String>? genderPrefs,
    int? ageMin,
    int? ageMax,
    int? distanceKm,
    String? messagingPref,
    bool? showExactDistance,
    bool? hideLastActive,
    bool? verifiedOnly,
    bool? appearInMenPool,
    bool? appearInWomenPool,
    bool? nbOnlyPool,
  }) async {}

  @override
  Future<VibeProfile?> fetchProfile(String uid) async =>
      _profiles.firstWhere((p) => p.uid == uid, orElse: () => _profiles.first);

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
  @override
  Future<void> deletePathsPresence() async {}
  @override
  Future<List<PathsInvite>> fetchPendingPathsInvites() async => [];

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
  
  @override
  Stream<List<BlindSession>> watchUserBlindSessions() => const Stream.empty();

  @override
  Future<void> respondBlindReveal(String sessionId) async {}

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
  Stream<List<Map<String, dynamic>>> watchMeltInvites() => const Stream.empty();

  @override
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {}

  @override
  Future<void> reportUser(
    String targetUid, {
    String? reason,
    String? details,
    String? context,
    String? contextId,
  }) async {}

  @override
  Future<void> blockUser(String targetUid) async {}

  @override
  Future<void> unblockUser(String targetUid) async {}

  @override
  Future<void> unmatchUser(String targetUid) async {}

  @override
  Future<List<String>> listBlockedUids() async => const [];

  @override
  Future<List<VibeProfile>> fetchLikes({int limit = 50}) async => _profiles;

  @override
  Future<LikedByResult> fetchLikedBy() async =>
      LikedByResult(count: _profiles.length, isPremium: false, profiles: const []);

  @override
  Future<Map<String, dynamic>> exportMyData() async => {'note': 'mock export'};

  @override
  Future<void> submitFeedback({required String category, required String message, String? email}) async {}

  @override
  Future<Map<String, bool>> getNotificationPrefs() async =>
      {'messages': true, 'matches': true, 'likes': true, 'pathInvites': true, 'freezeRoom': true, 'marketing': false};

  @override
  Future<void> updateNotificationPrefs(Map<String, bool> prefs) async {}

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {}

  @override
  Future<void> scheduleAccountDeletion() async {}

  @override
  Future<Map<String, dynamic>> fetchPoolSession() async {
    final now = DateTime.now();
    final opens = DateTime(now.year, now.month, now.day, 18, 0, 0);
    final closes = opens.add(const Duration(hours: 6));
    final isOpen = now.isAfter(opens) && now.isBefore(closes);
    return {
      'isOpen': isOpen,
      'opensAt': opens.toUtc().toIso8601String(),
      'closesAt': closes.toUtc().toIso8601String(),
    };
  }

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
      dna: CompatibilityDNA(
        overall: 92,
        lifestyle: 95,
        personality: 88,
        communication: 90,
        values: 94,
      ),
      interests: ['Art', 'Coffee', 'Travel'],
      bio: 'Adventure seeker | Coffee addict | Let\'s explore the city together ☕',
      distance: '2 km away',
    ),
    VibeProfile(
      uid: 'mock-alex',
      id: 2,
      name: 'Alex',
      age: 27,
      imageUrl:
          'https://images.unsplash.com/flagged/photo-1596479042555-9265a7fa7983?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx5b3VuZyUyMG1hbiUyMHBvcnRyYWl0fGVufDF8fHx8MTc2MDkzNjI2MHww&ixlib=rb-4.1.0&q=80&w=1080',
      photoUrls: <String>[],
      compatibility: 88,
      dna: CompatibilityDNA(
        overall: 88,
        lifestyle: 85,
        personality: 90,
        communication: 86,
        values: 92,
      ),
      interests: ['Fitness', 'Food', 'Movies'],
      bio: 'Fitness enthusiast | Foodie | Looking for meaningful connections 💪',
      distance: '5 km away',
    ),
  ];
}
