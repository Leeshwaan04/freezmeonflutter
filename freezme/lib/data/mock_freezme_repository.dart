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
  Future<void> createProfile(VibeProfile profile) async {}

  @override
  Future<void> likeProfile(String targetUid) async {}

  @override
  Future<void> skipProfile(String targetUid) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchMatches() async => const [];

  @override
  Stream<List<Map<String, dynamic>>> watchMatches() => Stream.value(const []);

  @override
  Future<void> updateProfilePhotos({
    required String uid,
    required List<String> photoUrls,
  }) async {}

  @override
  Future<VibeProfile?> fetchProfile(String uid) async =>
      _profiles.firstWhere((p) => p.uid == uid, orElse: () => _profiles.first);

  // Messaging (no-op)
  @override
  Future<void> sendMessage(ChatMessage message) async {}
  @override
  Stream<List<ChatMessage>> messagesForChat(String chatId) =>
      const Stream.empty();
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
}
