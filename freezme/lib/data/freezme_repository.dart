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

  // Messaging
  Future<void> sendMessage(ChatMessage message);
  Stream<List<ChatMessage>> messagesForChat(String chatId);
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
}
