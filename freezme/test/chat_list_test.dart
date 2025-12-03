import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freezme/main.dart' hide VibeProfile;
import 'package:freezme/ui/chat/chat_list_page.dart';
import 'package:freezme/data/freezme_repository.dart';
import 'dart:async';
import 'package:freezme/models/vibe_profile.dart';
import 'package:freezme/models/chat_message.dart';
import 'package:freezme/models/paths.dart';
import 'package:freezme/models/blinds.dart';

// Fake repository
class FakeFreezmeRepository implements FreezmeRepository {
  @override
  Stream<List<Map<String, dynamic>>> watchMatches() {
    return Stream.value([
      {
        'id': 'chat1',
        'name': 'Test User',
        'photoUrl': '',
        'lastMessage': 'Hello',
        'updatedAt': DateTime.now().toIso8601String(),
        'unread': 1,
        'status': 'sent',
        'isGroup': false,
      }
    ]);
  }

  @override
  Future<void> createProfile(VibeProfile profile) async {}

  @override
  Future<List<VibeProfile>> fetchDailyProfiles() async => [];

  @override
  Future<VibeProfile?> fetchProfile(String uid) async => null;

  @override
  Future<void> likeProfile(String targetUid) async {}

  @override
  Future<void> skipProfile(String targetUid) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchMatches() async => [];

  @override
  Future<void> updateProfilePhotos({required String uid, required List<String> photoUrls}) async {}

  @override
  Future<void> sendMessage(ChatMessage message) async {}

  @override
  Stream<List<ChatMessage>> messagesForChat(String chatId) => Stream.value([]);

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
  Stream<List<PathsPresence>> fetchNearbyPaths({required double radiusKm, required Set<String> intents, double? lat, double? lng}) => Stream.value([]);

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
}

void main() {
  testWidgets('ChatListPage renders correctly', (WidgetTester tester) async {
    final mockRepo = FakeFreezmeRepository();
    final controller = AppFlowController.test(repository: mockRepo);

    await tester.pumpWidget(
      AppFlowScope(
        controller: controller,
        child: const MaterialApp(
          home: ChatListPage(),
        ),
      ),
    );

    // Verify loading state or data
    await tester.pumpAndSettle();

    // Check if "Test User" is displayed
    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // Unread count
  });
}
