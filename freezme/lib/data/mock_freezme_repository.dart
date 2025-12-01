import '../models/vibe_profile.dart';
import 'freezme_repository.dart';
import '../models/chat_message.dart';
import '../models/paths.dart';
import '../models/blinds.dart';

/// Local-only repository that provides deterministic data for demos and tests.
class MockFreezmeRepository implements FreezmeRepository {
  const MockFreezmeRepository();

  @override
  Future<List<VibeProfile>> fetchDailyProfiles() async {
    return _profiles;
  }

  @override
  Future<void> createProfile(VibeProfile profile) async {
    // no-op in mock mode
  }

  @override
  Future<void> likeProfile(String targetUid) async {
    // no-op in mock mode
  }

  @override
  Future<void> skipProfile(String targetUid) async {
    // no-op in mock mode
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMatches() async {
    return const [];
  }

  // Messaging (mock no-ops)
  @override
  Future<void> sendMessage(ChatMessage message) async {}
  @override
  Stream<List<ChatMessage>> messagesForChat(String chatId) =>
      const Stream.empty();
  @override
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {}
  @override
  Future<void> signOut() async {}

  // Paths (mock)
  @override
  Future<void> upsertPathsPresence(PathsPresence presence) async {}
  @override
  Stream<List<PathsPresence>> fetchNearbyPaths({
    required double radiusKm,
    required Set<String> intents,
  }) =>
      const Stream.empty();
  @override
  Future<void> sendPathsInvite(PathsInvite invite) async {}
  @override
  Stream<PathsInvite> inviteStatus(String inviteId) => const Stream.empty();
  @override
  Future<void> cancelPathsInvite(String inviteId) async {}

  // Blinds (mock)
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
      photoUrls: <String>[
        'https://images.unsplash.com/flagged/photo-1596479042555-9265a7fa7983?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx5b3VuZyUyMG1hbiUyMHBvcnRyYWl0fGVufDF8fHx8MTc2MDkzNjI2MHww&ixlib=rb-4.1.0&q=80&w=1080',
      ],
      compatibility: 88,
      bio: 'Fitness enthusiast | Foodie | Looking for meaningful connections 💪',
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
      bio: 'Artist at heart | Music lover | Deep conversations over small talk 🎨',
      distance: '3 km away',
    ),
    VibeProfile(
      uid: 'mock-jordan',
      id: 4,
      name: 'Jordan',
      age: 29,
      imageUrl:
          'https://images.unsplash.com/photo-1504593811423-6dd665756598?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx1cmJhbiUyMG1hbiUyMHNtaWxpbmd8ZW58MXx8fHwxNzYwOTc4NTgxfDA&ixlib=rb-4.1.0&q=80&w=1080',
      photoUrls: <String>[
        'https://images.unsplash.com/photo-1504593811423-6dd665756598?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx1cmJhbiUyMG1hbiUyMHNtaWxpbmd8ZW58MXx8fHwxNzYwOTc4NTgxfDA&ixlib=rb-4.1.0&q=80&w=1080',
      ],
      compatibility: 90,
      bio: 'Architect | Takes sunset photos | Open to unexpected adventures 📸',
      distance: '1 km away',
    ),
    VibeProfile(
      uid: 'mock-meera',
      id: 5,
      name: 'Meera',
      age: 25,
      imageUrl:
          'https://images.unsplash.com/photo-1492567291473-fe3dfc175b45?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxpbmRpYW4lMjB3b21hbiUyMHNtaWxpbmd8ZW58MXx8fHwxNzYwOTc4NTk4fDA&ixlib=rb-4.1.0&q=80&w=1080',
      photoUrls: <String>[
        'https://images.unsplash.com/photo-1492567291473-fe3dfc175b45?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxpbmRpYW4lMjB3b21hbiUyMHNtaWxpbmd8ZW58MXx8fHwxNzYwOTc4NTk4fDA&ixlib=rb-4.1.0&q=80&w=1080',
      ],
      compatibility: 87,
      bio: 'Product designer | Writes poetry | Searching for a partner in creativity ✨',
      distance: '4 km away',
    ),
    VibeProfile(
      uid: 'mock-noah',
      id: 6,
      name: 'Noah',
      age: 28,
      imageUrl:
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx0ZWFjaGVyJTIwbWFuJTIwc21pbGluZ3xlbnwxfHx8fDE3NjA5Nzg2MDN8MA&ixlib=rb-4.1.0&q=80&w=1080',
      photoUrls: <String>[
        'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx0ZWFjaGVyJTIwbWFuJTIwc21pbGluZ3xlbnwxfHx8fDE3NjA5Nzg2MDN8MA&ixlib=rb-4.1.0&q=80&w=1080',
      ],
      compatibility: 91,
      bio: 'High school teacher | Trivia night regular | Let\'s cook something new 👨‍🍳',
      distance: '6 km away',
    ),
    VibeProfile(
      uid: 'mock-aanya',
      id: 7,
      name: 'Aanya',
      age: 23,
      imageUrl:
          'https://images.unsplash.com/photo-1510674485131-dc88d96369ac?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx1cmdhbiUyMGdpcmwxfGVufDF8fHx8MTc2MDk3ODYwOXww&ixlib=rb-4.1.0&q=80&w=1080',
      photoUrls: <String>[
        'https://images.unsplash.com/photo-1510674485131-dc88d96369ac?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHx1cmdhbiUyMGdpcmwxfGVufDF8fHx8MTc2MDk3ODYwOXww&ixlib=rb-4.1.0&q=80&w=1080',
      ],
      compatibility: 84,
      bio: 'Ayurvedic wellness coach | Practicing mindfulness daily | Looking for intentional dating 🧘‍♀️',
      distance: '2 km away',
    ),
    VibeProfile(
      uid: 'mock-leo',
      id: 8,
      name: 'Leo',
      age: 30,
      imageUrl:
          'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxnaXRhciUyMG1hbiUyMGpveWZ1bCUyMGZhY2V8ZW58MXx8fHwxNzYwOTc4NTczfDA&ixlib=rb-4.1.0&q=80&w=1080',
      photoUrls: <String>[
        'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxnaXRhciUyMG1hbiUyMGpveWZ1bCUyMGZhY2V8ZW58MXx8fHwxNzYwOTc4NTczfDA&ixlib=rb-4.1.0&q=80&w=1080',
      ],
      compatibility: 89,
      bio: 'Guitarist | Co-op gamer | Cooks elaborate brunches—join if you bring the playlist 🎶',
      distance: '7 km away',
    ),
  ];
}
