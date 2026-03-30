import 'dart:async';

/// Presence is now managed by the WebSocket layer via 'presence:ping' events.
/// This class is a no-op stub kept for API compatibility.
class PresenceService {
  PresenceService();

  PresenceService.disabled();

  /// No-op — WebSocket handles presence via ping events.
  Future<void> setStatus(String uid, {required String status}) async {}

  /// Returns an empty stream — presence state is not tracked locally.
  Stream<String?> watchStatus(String uid) => const Stream<String?>.empty();
}
