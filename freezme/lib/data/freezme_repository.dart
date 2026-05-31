import '../models/vibe_profile.dart';
import '../models/chat_message.dart';
import '../models/paths.dart';
import '../models/blinds.dart';

/// Result of the "Who Liked You" query. For non-premium users [profiles] are
/// blurred placeholders (no name/photo) and [count] drives the upsell.
class LikedByResult {
  const LikedByResult({
    required this.count,
    required this.isPremium,
    required this.profiles,
  });

  final int count;
  final bool isPremium;
  final List<VibeProfile> profiles;
}

abstract class FreezmeRepository {
  Future<List<VibeProfile>> fetchDailyProfiles();

  /// Fetches profiles for the "Tonight Algorithm" (Recency + Proximity).
  Future<List<VibeProfile>> fetchTonightPool({
    required double lat,
    required double lng,
    required String timezone,
  });

  Future<void> updateUserPreferences({
    required int ageMin,
    required int ageMax,
    required double distanceKm,
    required String bio,
  });

  Future<Map<String, dynamic>> fetchUserPreferences();

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
    // ── Level-Up prefs ───────────────────────────────────────────────────────
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
  Future<void> deletePathsPresence();
  Future<List<PathsInvite>> fetchPendingPathsInvites();

  // Blinds (Anonymous)
  Future<void> enqueueBlind(BlindQueueEntry entry);
  Future<void> dequeueBlind(String userId);
  Future<void> createBlindSession(BlindSession session);
  Stream<BlindSession> blindSessionUpdates(String sessionId);
  Stream<List<BlindSession>> watchUserBlindSessions();
  Future<void> respondBlindReveal(String sessionId);
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
  Stream<List<Map<String, dynamic>>> watchMeltInvites();
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  });

  // Safety & Trust
  Future<void> reportUser(
    String targetUid, {
    String? reason,
    String? details,
    String? context,
    String? contextId,
  });
  Future<void> blockUser(String targetUid);
  Future<void> unblockUser(String targetUid);
  Future<List<String>> listBlockedUids();
  Future<void> unmatchUser(String targetUid);

  // Likes
  Future<List<VibeProfile>> fetchLikes({int limit = 50});

  /// Who-Liked-You. Returns count + premium flag + (blurred for free) profiles.
  Future<LikedByResult> fetchLikedBy();

  // Account / data management
  Future<Map<String, dynamic>> exportMyData();
  Future<void> submitFeedback({
    required String category,
    required String message,
    String? email,
  });
  Future<Map<String, bool>> getNotificationPrefs();
  Future<void> updateNotificationPrefs(Map<String, bool> prefs);
  Future<void> changePassword({required String currentPassword, required String newPassword});
  Future<void> scheduleAccountDeletion();

  // Pool Session
  Future<Map<String, dynamic>> fetchPoolSession();
}
