import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vibe_profile.dart';
import '../models/chat_message.dart';
import '../models/paths.dart';
import '../models/blinds.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/websocket_service.dart';
import 'freezme_repository.dart';

/// EC2-backed implementation of FreezmeRepository.
/// Replaces FirestoreFreezmeRepository — all data goes through the REST API
/// with real-time updates via WebSockets.
class Ec2FreezmeRepository implements FreezmeRepository {
  Ec2FreezmeRepository({FreezmeRepository? fallback}) : _fallback = fallback;

  final FreezmeRepository? _fallback;
  final _client = ApiClient.instance;
  final _ws = WebSocketService.instance;

  // ── Profiles ───────────────────────────────────────────────────────────────

  @override
  Future<List<VibeProfile>> fetchDailyProfiles() async {
    try {
      final response =
          await _client.dio.get<List<dynamic>>('/profiles/daily-pool');
      return (response.data ?? [])
          .map((e) => VibeProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Ec2Repo] fetchDailyProfiles error: $e');
      return _fallback?.fetchDailyProfiles() ?? [];
    }
  }

  @override
  Future<List<VibeProfile>> fetchTonightPool({
    required double lat,
    required double lng,
    required String timezone,
  }) async {
    try {
      final response = await _client.dio.get<List<dynamic>>(
        '/profiles/daily-pool',
        queryParameters: {'lat': lat, 'lng': lng, 'timezone': timezone},
      );
      return (response.data ?? [])
          .map((e) => VibeProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Ec2Repo] fetchTonightPool error: $e');
      return _fallback?.fetchTonightPool(lat: lat, lng: lng, timezone: timezone) ?? [];
    }
  }

  @override
  Future<VibeProfile?> fetchProfile(String uid) async {
    try {
      final response =
          await _client.dio.get<Map<String, dynamic>>('/profiles/$uid');
      return VibeProfile.fromJson(response.data!);
    } catch (_) {
      return _fallback?.fetchProfile(uid);
    }
  }

  @override
  Future<void> createProfile(VibeProfile profile) async {
    await _client.dio.post<void>('/profiles', data: profile.toJson());
  }

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
  }) async {
    await _client.dio.post<void>('/profiles', data: {
      if (displayName != null) 'name': displayName,
      if (bio != null) 'bio': bio,
      if (age != null) 'age': age,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (gender != null) 'gender': gender,
      if (location != null) 'location': location,
      if (interests != null) 'interests': interests,
      if (allowBlindReveal != null) 'allowBlindReveal': allowBlindReveal,
      if (intent != null) 'intent': intent,
      if (personalityTraits != null) 'personalityTraits': personalityTraits,
      if (lifestyleFactors != null) 'lifestyleFactors': lifestyleFactors,
      if (archetype != null) 'archetype': archetype,
      if (energyType != null) 'energyType': energyType,
      if (paceSignal != null) 'paceSignal': paceSignal,
      if (promptAnswer != null) 'promptAnswer': promptAnswer,
      if (presenceWindows != null) 'presenceWindows': presenceWindows,
      // Level-Up prefs
      if (genderPrefs != null) 'genderPrefs': genderPrefs,
      if (ageMin != null) 'ageMin': ageMin,
      if (ageMax != null) 'ageMax': ageMax,
      if (distanceKm != null) 'distanceKm': distanceKm,
      if (messagingPref != null) 'messagingPref': messagingPref,
      if (showExactDistance != null) 'showExactDistance': showExactDistance,
      if (hideLastActive != null) 'hideLastActive': hideLastActive,
      if (verifiedOnly != null) 'verifiedOnly': verifiedOnly,
      if (appearInMenPool != null) 'appearInMenPool': appearInMenPool,
      if (appearInWomenPool != null) 'appearInWomenPool': appearInWomenPool,
      if (nbOnlyPool != null) 'nbOnlyPool': nbOnlyPool,
    });
  }

  @override
  Future<void> updateProfilePhotos({
    required String uid,
    required List<String> photoUrls,
  }) async {
    await _client.dio.post<void>('/profiles', data: {
      'imageUrl': photoUrls.isNotEmpty ? photoUrls.first : null,
    });
  }

  @override
  Future<void> updateUserPreferences({
    required int ageMin,
    required int ageMax,
    required double distanceKm,
    required String bio,
  }) async {
    await _client.dio.post<void>('/profiles', data: {
      'bio': bio,
      'ageMin': ageMin,
      'ageMax': ageMax,
      'distanceKm': distanceKm,
    });
  }

  @override
  Future<Map<String, dynamic>> fetchUserPreferences() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('/profiles/me');
      return response.data ?? {};
    } catch (e) {
      debugPrint('[Ec2Repo] fetchUserPreferences error: $e');
      return {};
    }
  }

  // ── Matching ───────────────────────────────────────────────────────────────

  @override
  Future<void> likeProfile(String targetUid) async {
    await _client.dio.post<void>('/matching/like', data: {'targetUid': targetUid});
  }

  @override
  Future<void> skipProfile(String targetUid) async {
    await _client.dio.post<void>('/matching/skip', data: {'targetUid': targetUid});
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMatches() async {
    try {
      // Use /chats so the returned `id` is the Chat id (needed to load messages)
      // Each chat includes otherProfile with name/imageUrl, and messages[0] for preview
      final response =
          await _client.dio.get<List<dynamic>>('/chats');
      return (response.data ?? [])
          .cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[Ec2Repo] fetchMatches error: $e');
      return [];
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchMatches() {
    // Emit initial + update on each new match/message event
    final controller = StreamController<List<Map<String, dynamic>>>();

    Future<void> fetch() async {
      final chats = await fetchMatches();
      if (!controller.isClosed) controller.add(chats);
    }

    fetch();
    // Refresh chat list when a new match or message arrives
    final sub1 = _ws.onMatchNew.listen((_) => fetch());
    final sub2 = _ws.onChatMessage.listen((_) => fetch());
    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    return controller.stream;
  }

  // ── Messaging ──────────────────────────────────────────────────────────────

  @override
  Future<void> sendMessage(ChatMessage message) async {
    if (!_ws.isConnected) {
      // Socket is offline — throw so the UI can show the failed/retry state.
      // The WebSocketService will reconnect automatically in the background.
      throw Exception('No connection. Please try again.');
    }
    _ws.sendChatMessage(
      chatId: message.chatId,
      text: message.text,
      clientMsgId: message.clientMsgId ?? '',
    );
  }

  static String _chatCacheKey(String chatId) => 'chat_cache_$chatId';
  static const int _maxCachedMessages = 100;

  Future<List<ChatMessage>> _loadCachedMessages(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_chatCacheKey(chatId));
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistMessages(String chatId, List<ChatMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep only the most recent N messages to limit storage
      final toSave = messages.length > _maxCachedMessages
          ? messages.sublist(messages.length - _maxCachedMessages)
          : messages;
      await prefs.setString(_chatCacheKey(chatId), jsonEncode(toSave.map((m) => m.toJson()).toList()));
    } catch (_) {}
  }

  @override
  Stream<List<ChatMessage>> messagesForChat(String chatId, {int limit = 50}) {
    final controller = StreamController<List<ChatMessage>>();
    final List<ChatMessage> buffer = [];

    Future<void> loadHistory() async {
      // 1. Serve cached messages immediately so chat isn't blank on restart
      final cached = await _loadCachedMessages(chatId);
      if (cached.isNotEmpty && !controller.isClosed) {
        buffer.addAll(cached);
        controller.add(List.from(buffer));
      }

      // 2. Fetch fresh from server
      try {
        final response = await _client.dio.get<List<dynamic>>(
          '/chats/$chatId/messages',
          queryParameters: {'limit': limit},
        );
        final msgs = (response.data ?? [])
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        buffer
          ..clear()
          ..addAll(msgs);
        if (!controller.isClosed) controller.add(List.from(buffer));
        // Persist fresh messages to cache
        unawaited(_persistMessages(chatId, buffer));
      } catch (e) {
        debugPrint('[Ec2Repo] loadHistory error: $e');
        // Cache already emitted above — no action needed
      }
    }

    loadHistory();

    final sub = _ws.chatMessages(chatId).listen((event) {
      final msg = ChatMessage.fromJson(
          event['message'] as Map<String, dynamic>);
      buffer.add(msg);
      if (!controller.isClosed) controller.add(List.from(buffer));
      // Persist incrementally on every new message
      unawaited(_persistMessages(chatId, buffer));
    });

    controller.onCancel = sub.cancel;
    return controller.stream;
  }

  @override
  Future<List<ChatMessage>> loadMoreMessages(
    String chatId, {
    required ChatMessage lastMessage,
    int limit = 50,
  }) async {
    try {
      final response = await _client.dio.get<List<dynamic>>(
        '/chats/$chatId/messages',
        queryParameters: {
          'limit': limit,
          'before': lastMessage.sentAt.toIso8601String(),
        },
      );
      return (response.data ?? [])
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> markChatAsRead(String chatId) async {
    // Handled by WebSocket read receipts
  }

  @override
  Future<void> updateOnlineStatus(String userId, bool isOnline) async {
    if (isOnline) _ws.pingPresence();
  }

  @override
  Future<void> signOut() async {
    _ws.disconnect();
    await AuthService.instance.signOut();
  }

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

  // ── Paths ──────────────────────────────────────────────────────────────────

  @override
  Future<void> upsertPathsPresence(PathsPresence presence) async {
    await _client.dio.post<void>('/paths/presence', data: {
      'lat': presence.lat,
      'lng': presence.lng,
      'intents': presence.intents.toList(),
      'radiusKm': presence.radiusKm,
    });
  }

  @override
  Stream<List<PathsPresence>> fetchNearbyPaths({
    required double radiusKm,
    required Set<String> intents,
    double? lat,
    double? lng,
  }) {
    final controller = StreamController<List<PathsPresence>>();

    Future<void> load() async {
      try {
        final response = await _client.dio.get<List<dynamic>>(
          '/paths/nearby',
          queryParameters: {
            if (lat != null) 'lat': lat,
            if (lng != null) 'lng': lng,
            'radius': radiusKm,
          },
        );
        final presences = (response.data ?? [])
            .map((e) => PathsPresence.fromJson(e as Map<String, dynamic>))
            .toList();
        if (!controller.isClosed) controller.add(presences);
      } catch (e) {
        debugPrint('[Ec2Repo] fetchNearbyPaths error: $e');
        if (!controller.isClosed) controller.add([]);
      } finally {
        await controller.close();
      }
    }

    load();
    return controller.stream;
  }

  @override
  Future<String> sendPathsInvite({
    required String receiverUid,
    required String intent,
  }) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/paths/invite',
      data: {'receiverUid': receiverUid, 'intent': intent},
    );
    return response.data!['id'] as String;
  }

  @override
  Stream<PathsInvite> inviteStatus(String inviteId) {
    return _ws.onPathsInvite
        .where((e) => e['invite']?['id'] == inviteId)
        .map((e) => PathsInvite.fromJson(e['invite'] as Map<String, dynamic>));
  }

  @override
  Future<void> cancelPathsInvite(String inviteId) async {
    await _client.dio.post<void>(
      '/paths/invite/$inviteId/respond',
      data: {'status': 'cancelled'},
    );
  }

  @override
  Future<void> deletePathsPresence() async {
    try {
      await _client.dio.delete<void>('/paths/presence');
    } catch (_) {}
  }

  @override
  Future<List<PathsInvite>> fetchPendingPathsInvites() async {
    try {
      final response = await _client.dio.get<List<dynamic>>(
        '/paths/invites',
        queryParameters: {'status': 'pending'},
      );
      return (response.data ?? [])
          .map((e) => PathsInvite.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Blinds ─────────────────────────────────────────────────────────────────

  @override
  Future<void> enqueueBlind(BlindQueueEntry entry) async {
    await _client.dio.post<void>('/blinds/enqueue', data: {
      'intent': entry.intent,
      'distanceBucket': entry.distanceBucket,
    });
  }

  @override
  Future<void> dequeueBlind(String userId) async {
    await _client.dio.delete<void>('/blinds/enqueue');
  }

  @override
  Future<void> createBlindSession(BlindSession session) async {
    // Session creation is server-side on enqueue
  }

  @override
  Stream<BlindSession> blindSessionUpdates(String sessionId) {
    return _ws.onBlindPhase
        .where((e) => e['sessionId'] == sessionId)
        .map((e) => BlindSession.fromJson(e['session'] as Map<String, dynamic>));
  }

  @override
  Stream<List<BlindSession>> watchUserBlindSessions() {
    final controller = StreamController<List<BlindSession>>();
    final sub = _ws.onBlindSession.listen((event) {
      final session =
          BlindSession.fromJson(event['session'] as Map<String, dynamic>);
      controller.add([session]);
    });
    controller.onCancel = sub.cancel;
    return controller.stream;
  }

  @override
  Future<void> respondBlindReveal(String sessionId) async {
    _ws.revealBlind(sessionId: sessionId);
  }

  @override
  Future<void> reportBlindSession(String sessionId, String reason) async {
    await _client.dio.post<void>(
      '/blinds/session/$sessionId/report',
      data: {'reason': reason},
    );
  }

  // ── Feed ───────────────────────────────────────────────────────────────────

  @override
  Future<String> createPost({
    required List<String> photoUrls,
    String? caption,
    required String visibility,
  }) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/feed',
      data: {
        'content': caption ?? '',
        'photoUrls': photoUrls,
        'visibility': visibility,
      },
    );
    return response.data!['id'] as String;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchFeed({int limit = 20}) {
    final controller = StreamController<List<Map<String, dynamic>>>();

    Future<void> load() async {
      try {
        final response = await _client.dio.get<List<dynamic>>(
          '/feed',
          queryParameters: {'limit': limit},
        );
        if (!controller.isClosed) {
          controller.add((response.data ?? []).cast<Map<String, dynamic>>());
        }
      } catch (e) {
        debugPrint('[Ec2Repo] watchFeed error: $e');
      }
    }

    load();
    return controller.stream;
  }

  @override
  Future<List<Map<String, dynamic>>> loadMorePosts({
    required String lastPostId,
    int limit = 20,
  }) async {
    try {
      final response = await _client.dio.get<List<dynamic>>(
        '/feed',
        queryParameters: {'limit': limit, 'before': lastPostId},
      );
      return (response.data ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    await _client.dio.delete<void>('/feed/$postId');
  }

  @override
  Future<void> likePost(String postId) async {
    await _client.dio.post<void>('/feed/$postId/like');
  }

  @override
  Future<void> unlikePost(String postId) async {
    await _client.dio.delete<void>('/feed/$postId/like');
  }

  @override
  Future<void> addComment({
    required String postId,
    required String text,
  }) async {
    await _client.dio.post<void>('/feed/$postId/comments', data: {'text': text});
  }

  @override
  Stream<List<Map<String, dynamic>>> watchComments(String postId) {
    final controller = StreamController<List<Map<String, dynamic>>>();

    Future<void> load() async {
      try {
        final response = await _client.dio
            .get<List<dynamic>>('/feed/$postId/comments');
        if (!controller.isClosed) {
          controller.add((response.data ?? []).cast<Map<String, dynamic>>());
        }
      } catch (_) {}
    }

    load();
    return controller.stream;
  }

  @override
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    await _client.dio.delete<void>('/feed/$postId/comments/$commentId');
  }

  @override
  Stream<List<Map<String, dynamic>>> watchMeltInvites() {
    final controller = StreamController<List<Map<String, dynamic>>>();
    final List<Map<String, dynamic>> buffer = [];

    Future<void> loadInitial() async {
      try {
        final response =
            await _client.dio.get<List<dynamic>>('/melt/sessions');
        buffer
          ..clear()
          ..addAll((response.data ?? []).cast<Map<String, dynamic>>());
        if (!controller.isClosed) controller.add(List.from(buffer));
      } catch (_) {}
    }

    loadInitial();

    final sub = _ws.onMeltInvite.listen((event) {
      buffer.add(event);
      if (!controller.isClosed) controller.add(List.from(buffer));
    });

    controller.onCancel = sub.cancel;
    return controller.stream;
  }

  // ── Safety ─────────────────────────────────────────────────────────────────

  @override
  Future<void> reportUser(String targetUid) async {
    try {
      await _client.dio.post<void>(
        '/users/$targetUid/report',
        data: {'reason': 'user_reported'},
      );
    } catch (e) {
      debugPrint('[Ec2Repo] reportUser error: $e');
    }
  }

  // ── Pool Session ────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> fetchPoolSession() async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>('/pool/session');
      return response.data ?? {};
    } catch (e) {
      debugPrint('[Ec2Repo] fetchPoolSession error: $e');
      return {};
    }
  }
}
