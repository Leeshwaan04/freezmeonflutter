import 'package:freezme/data/freezme_repository.dart';
import 'package:freezme/models/vibe_profile.dart';
import 'package:freezme/models/chat_message.dart';
import 'package:freezme/models/paths.dart';
import 'package:freezme/models/blinds.dart';
import 'dart:async';

/// Minimal stub implementation of [FreezmeRepository] used only for unit tests.
class MockFreezmeRepository implements FreezmeRepository {
  @override
  Future<List<VibeProfile>> fetchDailyProfiles() async => _dummyProfiles();

  @override
  Future<List<VibeProfile>> fetchTonightPool({required double lat, required double lng, required String timezone}) async => _dummyProfiles();

  // Helper method to generate dummy profiles for testing
  List<VibeProfile> _dummyProfiles() {
    return [
      VibeProfile(
        uid: 'test_user_1',
        name: 'Alex',
        age: 25,
        imageUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
        photoUrls: [],
        compatibility: 85,
        bio: 'Coffee enthusiast',
        distance: '2 km away',
      ),
      VibeProfile(
        uid: 'test_user_2',
        name: 'Jordan',
        age: 27,
        imageUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d',
        photoUrls: [],
        compatibility: 90,
        bio: 'Adventure seeker',
        distance: '5 km away',
      ),
    ];
  }

  @override
  Future<void> updateUserPreferences({required int ageMin, required int ageMax, required double distanceKm, required String bio}) async {}

  @override
  Future<Map<String, dynamic>> fetchUserPreferences() async => {};

  @override
  Future<void> createProfile(VibeProfile profile) async {}

  @override
  Future<void> likeProfile(String targetUid) async {}

  @override
  Future<void> skipProfile(String targetUid) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchMatches() async => [];

  @override
  Stream<List<Map<String, dynamic>>> watchMatches() => const Stream.empty();

  @override
  Future<void> updateProfilePhotos({required String uid, required List<String> photoUrls}) async {}

  @override
  Future<VibeProfile?> fetchProfile(String uid) async => null;

  @override
  Future<void> updateProfile({required String uid, String? displayName, String? bio, int? age, String? gender, String? location, List<String>? interests, bool? isPremium}) async {}

  @override
  Future<void> sendMessage(ChatMessage message) async {}

  @override
  Stream<List<ChatMessage>> messagesForChat(String chatId, {int limit = 50}) => const Stream.empty();

  @override
  Future<List<ChatMessage>> loadMoreMessages(String chatId, {required ChatMessage lastMessage, int limit = 50}) async => [];

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
  Stream<List<PathsPresence>> fetchNearbyPaths({required double radiusKm, required Set<String> intents, double? lat, double? lng}) => const Stream.empty();

  @override
  Future<String> sendPathsInvite({required String receiverUid, required String intent}) async => '';

  @override
  Stream<PathsInvite> inviteStatus(String inviteId) => const Stream.empty();

  @override
  Future<void> cancelPathsInvite(String inviteId) async {}

  @override
  Future<void> enqueueBlind(BlindQueueEntry entry) async {}

  @override
  Future<void> dequeueBlind(String userId) async {}

  @override
  Future<void> createBlindSession(BlindSession session) async {}

  @override
  Stream<BlindSession> blindSessionUpdates(String sessionId) => const Stream.empty();

  @override
  Future<void> reportBlindSession(String sessionId, String reason) async {}

  @override
  Future<String> createPost({required List<String> photoUrls, String? caption, required String visibility}) async => '';

  @override
  Stream<List<Map<String, dynamic>>> watchFeed({int limit = 20}) => const Stream.empty();

  @override
  Future<List<Map<String, dynamic>>> loadMorePosts({required String lastPostId, int limit = 20}) async => [];

  @override
  Future<void> deletePost(String postId) async {}

  @override
  Future<void> likePost(String postId) async {}

  @override
  Future<void> unlikePost(String postId) async {}

  @override
  Future<void> addComment({required String postId, required String text}) async {}

  @override
  Stream<List<Map<String, dynamic>>> watchComments(String postId) => const Stream.empty();

  @override
  Future<void> deleteComment({required String postId, required String commentId}) async {}
}
