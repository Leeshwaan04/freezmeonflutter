import 'package:cloud_functions/cloud_functions.dart';

import '../models/vibe_profile.dart';
import '../models/chat_message.dart';
import '../models/paths.dart';
import '../models/blinds.dart';
import 'freezme_repository.dart';
import 'mock_freezme_repository.dart';

typedef ProfileJson = Map<String, dynamic>;

typedef ProfileListBuilder = List<VibeProfile> Function(List<ProfileJson> json);

typedef ProfileSerializer = ProfileJson Function(VibeProfile profile);

typedef ProfileAction = Map<String, dynamic> Function({required String targetUid});

typedef VoidResponse = void Function(dynamic response);

typedef MatchesResponseBuilder = List<Map<String, dynamic>> Function(List<Map<String, dynamic>> json);

typedef MatchListBuilder = List<Map<String, dynamic>> Function(List<Map<String, dynamic>> data);

typedef MatchResponse = Map<String, dynamic> Function(dynamic response);

class CloudFunctionsFreezmeRepository implements FreezmeRepository {
  CloudFunctionsFreezmeRepository({
    FirebaseFunctions? functions,
    FreezmeRepository? fallback,
    ProfileListBuilder? profileBuilder,
    ProfileSerializer? serializer,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _fallback = fallback ?? const MockFreezmeRepository(),
        _profileBuilder = profileBuilder ?? _defaultProfileBuilder,
        _serializer = serializer ?? _defaultSerializer;

  final FirebaseFunctions _functions;
  final FreezmeRepository _fallback;
  final ProfileListBuilder _profileBuilder;
  final ProfileSerializer _serializer;

  @override
  Future<List<VibeProfile>> fetchDailyProfiles() async {
    try {
      final response = await _functions
          .httpsCallable('getDailyPool')
          .call(<String, dynamic>{'limit': 20});

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final profiles = data['profiles'];
        if (profiles is List) {
          return _profileBuilder(
            profiles.whereType<Map<String, dynamic>>().toList(),
          );
        }
      }
    } catch (_) {
      // fall back to mock data when the function fails or returns bad data
    }

    return _fallback.fetchDailyProfiles();
  }

  @override
  Future<void> createProfile(VibeProfile profile) async {
    try {
      await _functions
          .httpsCallable('createProfile')
          .call(_serializer(profile));
    } catch (_) {
      await _fallback.createProfile(profile);
    }
  }

  @override
  Future<void> likeProfile(String targetUid) async {
    try {
      await _functions
          .httpsCallable('likeProfile')
          .call(<String, dynamic>{'targetUid': targetUid});
    } catch (_) {
      await _fallback.likeProfile(targetUid);
    }
  }

  @override
  Future<void> skipProfile(String targetUid) async {
    try {
      await _functions
          .httpsCallable('skipProfile')
          .call(<String, dynamic>{'targetUid': targetUid});
    } catch (_) {
      await _fallback.skipProfile(targetUid);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMatches() async {
    try {
      final response = await _functions.httpsCallable('getMatches').call();
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final matches = data['matches'];
        if (matches is List) {
          return matches.whereType<Map<String, dynamic>>().toList();
        }
      }
    } catch (_) {
      // fall back below
    }
    return _fallback.fetchMatches();
  }

  @override
  Future<void> updateProfilePhotos({
    required String uid,
    required List<String> photoUrls,
  }) =>
      _fallback.updateProfilePhotos(uid: uid, photoUrls: photoUrls);

  @override
  Future<VibeProfile?> fetchProfile(String uid) =>
      _fallback.fetchProfile(uid);

  static List<VibeProfile> _defaultProfileBuilder(List<ProfileJson> json) {
    return json
        .map(
          (item) => VibeProfile.fromJson(item),
        )
        .toList();
  }

  static ProfileJson _defaultSerializer(VibeProfile profile) => profile.toJson();

  // Unimplemented stubs for interface completeness; delegate to fallback
  @override
  Future<void> sendMessage(ChatMessage message) =>
      _fallback.sendMessage(message);
  @override
  Stream<List<ChatMessage>> messagesForChat(String chatId) =>
      _fallback.messagesForChat(chatId);
  @override
  Future<void> updateOnlineStatus(String userId, bool isOnline) =>
      _fallback.updateOnlineStatus(userId, isOnline);
  @override
  Future<void> signOut() => _fallback.signOut();
  @override
  Future<void> upsertPathsPresence(PathsPresence presence) =>
      _fallback.upsertPathsPresence(presence);
  @override
  Stream<List<PathsPresence>> fetchNearbyPaths({
    required double radiusKm,
    required Set<String> intents,
    double? lat,
    double? lng,
  }) =>
      _fallback.fetchNearbyPaths(
        radiusKm: radiusKm,
        intents: intents,
        lat: lat,
        lng: lng,
      );
  @override
  Future<String> sendPathsInvite({
    required String receiverUid,
    required String intent,
  }) =>
      _fallback.sendPathsInvite(receiverUid: receiverUid, intent: intent);
  @override
  Stream<PathsInvite> inviteStatus(String inviteId) =>
      _fallback.inviteStatus(inviteId);
  @override
  Future<void> cancelPathsInvite(String inviteId) =>
      _fallback.cancelPathsInvite(inviteId);
  @override
  Future<void> enqueueBlind(BlindQueueEntry entry) =>
      _fallback.enqueueBlind(entry);
  @override
  Future<void> dequeueBlind(String userId) => _fallback.dequeueBlind(userId);
  @override
  Future<void> createBlindSession(BlindSession session) =>
      _fallback.createBlindSession(session);
  @override
  Stream<BlindSession> blindSessionUpdates(String sessionId) =>
      _fallback.blindSessionUpdates(sessionId);
  @override
  Future<void> reportBlindSession(String sessionId, String reason) =>
      _fallback.reportBlindSession(sessionId, reason);
}
