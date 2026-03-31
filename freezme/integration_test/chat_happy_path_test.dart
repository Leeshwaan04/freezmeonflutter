import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:freezme/main.dart';
import 'package:freezme/models/chat_message.dart';
import 'package:freezme/models/vibe_profile.dart';
import 'package:freezme/data/mock_freezme_repository.dart';
import 'package:freezme/services/melt_chat_service.dart';
import 'package:freezme/services/photo_upload_service.dart';
import 'package:freezme/services/iap_service.dart';

// ---------------------------------------------------------------------------
// Test-only repository that records sent messages and re-emits them so the
// chat StreamBuilder can actually render the bubble.
// ---------------------------------------------------------------------------
class _TestChatRepository extends MockFreezmeRepository {
  final _controller = StreamController<List<ChatMessage>>.broadcast();
  final List<ChatMessage> sent = [];

  @override
  Stream<List<ChatMessage>> messagesForChat(String chatId,
      {int limit = 50}) =>
      _controller.stream;

  @override
  Future<void> sendMessage(ChatMessage message) async {
    sent.add(message);
    _controller.add(List.unmodifiable(sent));
  }

  void dispose() => _controller.close();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Chat happy path', () {
    late _TestChatRepository repo;

    setUp(() => repo = _TestChatRepository());
    tearDown(() => repo.dispose());

    testWidgets(
      'User can open a chat, type a message and see it delivered',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        await tester.binding.setSurfaceSize(const Size(1080, 2160));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          FreezmeApp(
            controllerBuilder: () async => AppFlowController.test(
              prefs: prefs,
              photoUploadService: MockPhotoUploadService(),
              meltChatService: MockMeltChatService(),
              repository: repo,
              iapService: IAPService(repo),
              testCurrentUserId: 'test-uid-bob',
            ),
          ),
        );

        // Wait for splash → authGate
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        // Navigate directly to the chat screen via the flow controller.
        final flowElement = tester.element(find.byType(FlowNavigator));
        final flow = AppFlowScope.of(flowElement, listen: false);

        // Open chat with mock-priya (chatId stored as profile uid)
        flow.openChatDetail(
          const VibeProfile(
            uid: 'chat_priya',
            id: 1,
            name: 'Priya',
            age: 24,
            imageUrl: '',
            compatibility: 92,
            bio: '',
            distance: '',
          ),
          chatId: 'chat_priya',
        );
        await tester.pumpAndSettle();

        // ── Verify chat screen elements ────────────────────────────────────
        expect(find.text('Priya'), findsOneWidget,
            reason: 'Profile name should appear in the chat header');
        expect(find.byType(TextField), findsOneWidget,
            reason: 'Message input field should be present');
        expect(find.byIcon(Icons.send_rounded), findsOneWidget,
            reason: 'Send button should be present');

        // ── Type a message ─────────────────────────────────────────────────
        const msg = 'Hi Priya! This is a happy-path test message.';
        await tester.enterText(find.byType(TextField), msg);
        await tester.pump();

        // Verify text appeared in the field
        expect(find.text(msg), findsOneWidget);

        // ── Send it ────────────────────────────────────────────────────────
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pump(); // optimistic setState
        await tester.pump(const Duration(milliseconds: 50)); // repo.sendMessage

        // ── Message bubble is visible ──────────────────────────────────────
        expect(find.text(msg), findsOneWidget,
            reason: 'Sent message should appear as a bubble');

        // ── Stream delivers the message back → bubble stays visible ────────
        await tester.pumpAndSettle();
        expect(find.text(msg), findsOneWidget,
            reason: 'Message should still be visible after stream update');

        // ── Repository recorded the send ───────────────────────────────────
        expect(repo.sent, hasLength(1));
        expect(repo.sent.first.text, msg);
        expect(repo.sent.first.chatId, 'chat_priya');
        expect(repo.sent.first.senderId, 'test-uid-bob');

        // ── Delivery status icon is shown (not failed) ─────────────────────
        // After sendMessage completes the status transitions from pending→sent.
        // Icons.check == MessageStatus.sent
        expect(find.byIcon(Icons.check), findsWidgets,
            reason: 'Sent status icon should appear on the message bubble');

        // ── Back navigation returns to chat list ───────────────────────────
        await tester.tap(find.byIcon(Icons.chevron_left));
        await tester.pumpAndSettle();

        expect(find.text('Chats'), findsOneWidget,
            reason: 'Back button should return to the bottom nav');
      },
    );
  });
}
