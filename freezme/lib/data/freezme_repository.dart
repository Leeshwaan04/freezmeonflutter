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

  // Messaging
  Future<void> sendMessage(ChatMessage message);
  Stream<List<ChatMessage>> messagesForChat(String chatId);
  Future<void> updateOnlineStatus(String userId, bool isOnline);
  Future<void> signOut();

  // Paths (Nearby)
  Future<void> upsertPathsPresence(PathsPresence presence);
  Stream<List<PathsPresence>> fetchNearbyPaths({
    required double radiusKm,
    required Set<String> intents,
  });
  Future<void> sendPathsInvite(PathsInvite invite);
  Stream<PathsInvite> inviteStatus(String inviteId);
  Future<void> cancelPathsInvite(String inviteId);

  // Blinds (Anonymous)
  Future<void> enqueueBlind(BlindQueueEntry entry);
  Future<void> dequeueBlind(String userId);
  Future<void> createBlindSession(BlindSession session);
  Stream<BlindSession> blindSessionUpdates(String sessionId);
  Future<void> reportBlindSession(String sessionId, String reason);
}
