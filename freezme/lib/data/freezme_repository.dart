import '../models/vibe_profile.dart';
import '../models/chat_message.dart';
import '../models/paths.dart';
import '../models/blinds.dart';

abstract class FreezmeRepository {
  Future<List<VibeProfile>> fetchDailyProfiles();
  Future<void> createProfile(VibeProfile profile);
  Future<void> likeProfile(String targetUid);
  Future<void> skipProfile(String targetUid);
  Future<List<Map<String, dynamic>>> fetchMatches();
  Stream<List<Map<String, dynamic>>> watchMatches(); // Real-time chat updates
  Future<void> updateProfilePhotos({
    required String uid,
    required List<String> photoUrls,
  });
  Future<VibeProfile?> fetchProfile(String uid);
  
  // Profile Management
  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? bio,
    int? age,
    String? location,
    List<String>? interests,
  });

  // Messaging
  Future<void> sendMessage(ChatMessage message);
  Stream<List<ChatMessage>> messagesForChat(String chatId, {int limit = 50});
  Future<List<ChatMessage>> loadMoreMessages(String chatId, {required ChatMessage lastMessage, int limit = 50});
  Future<void> markChatAsRead(String chatId);
  Future<void> updateOnlineStatus(String userId, bool isOnline);
  Future<void> signOut();

  // Chat Management
  Future<void> deleteChat(String chatId);
  Future<void> pinChat(String chatId, bool pin);
  Future<void> muteChat(String chatId, bool mute);
  Future<void> archiveChat(String chatId, bool archive);
  Future<void> updateTypingStatus(String chatId, bool isTyping);

  // Paths (Nearby)
  Future<void> upsertPathsPresence(PathsPresence presence);
  Stream<List<PathsPresence>> fetchNearbyPaths({
    required double radiusKm,
    required Set<String> intents,
    double? lat,
    double? lng,
  });
  Future<String> sendPathsInvite({
    required String receiverUid,
    required String intent,
  });
  Stream<PathsInvite> inviteStatus(String inviteId);
  Future<void> cancelPathsInvite(String inviteId);

  // Blinds (Anonymous)
  Future<void> enqueueBlind(BlindQueueEntry entry);
  Future<void> dequeueBlind(String userId);
  Future<void> createBlindSession(BlindSession session);
  Stream<BlindSession> blindSessionUpdates(String sessionId);
  Future<void> reportBlindSession(String sessionId, String reason);

  // Feed (Social Posts)
  Future<String> createPost({
    required List<String> photoUrls,
    String? caption,
    required String visibility,
  });
  Stream<List<Map<String, dynamic>>> watchFeed({int limit = 20});
  Future<List<Map<String, dynamic>>> loadMorePosts({
    required String lastPostId,
    int limit = 20,
  });
  Future<void> deletePost(String postId);
  Future<void> likePost(String postId);
  Future<void> unlikePost(String postId);
  Future<void> addComment({
    required String postId,
    required String text,
  });
  Stream<List<Map<String, dynamic>>> watchComments(String postId);
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  });
}
