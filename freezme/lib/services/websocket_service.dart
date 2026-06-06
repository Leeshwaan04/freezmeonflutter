import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_client.dart';

const _kWsUrl = String.fromEnvironment(
  'WS_BASE_URL',
  defaultValue: 'https://api.freezme.in',
);

/// Stream-based wrapper around socket.io-client.
/// Replaces all Firestore real-time subscriptions for chat, presence, and sessions.
class WebSocketService {
  WebSocketService._();

  static final WebSocketService instance = WebSocketService._();

  io.Socket? _socket;
  bool _connected = false;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;

  // Per-event stream controllers
  final _chatMessageCtrl    = StreamController<Map<String, dynamic>>.broadcast();
  final _chatAckCtrl        = StreamController<Map<String, dynamic>>.broadcast();
  final _chatStatusCtrl     = StreamController<Map<String, dynamic>>.broadcast();
  final _chatReadCtrl       = StreamController<Map<String, dynamic>>.broadcast();
  final _chatErrorCtrl      = StreamController<Map<String, dynamic>>.broadcast();
  final _matchNewCtrl       = StreamController<Map<String, dynamic>>.broadcast();
  final _matchRemovedCtrl   = StreamController<Map<String, dynamic>>.broadcast();
  final _meltInviteCtrl     = StreamController<Map<String, dynamic>>.broadcast();
  final _meltStatusCtrl     = StreamController<Map<String, dynamic>>.broadcast();
  final _blindSessionCtrl   = StreamController<Map<String, dynamic>>.broadcast();
  final _blindPhaseCtrl     = StreamController<Map<String, dynamic>>.broadcast();
  final _pathsInviteCtrl    = StreamController<Map<String, dynamic>>.broadcast();
  final _freezeRoomAnswerCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _freezeRoomRevealCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _freezeRoomClosedCtrl = StreamController<Map<String, dynamic>>.broadcast();

  // ── Exposed streams ──────────────────────────────────────────────────────────
  Stream<Map<String, dynamic>> get onChatMessage    => _chatMessageCtrl.stream;
  Stream<Map<String, dynamic>> get onChatAck        => _chatAckCtrl.stream;
  Stream<Map<String, dynamic>> get onChatStatus     => _chatStatusCtrl.stream;
  Stream<Map<String, dynamic>> get onChatRead       => _chatReadCtrl.stream;
  Stream<Map<String, dynamic>> get onChatError      => _chatErrorCtrl.stream;
  Stream<Map<String, dynamic>> get onMatchNew       => _matchNewCtrl.stream;
  Stream<Map<String, dynamic>> get onMatchRemoved   => _matchRemovedCtrl.stream;
  Stream<Map<String, dynamic>> get onMeltInvite     => _meltInviteCtrl.stream;
  Stream<Map<String, dynamic>> get onMeltStatus     => _meltStatusCtrl.stream;
  Stream<Map<String, dynamic>> get onBlindSession   => _blindSessionCtrl.stream;
  Stream<Map<String, dynamic>> get onBlindPhase     => _blindPhaseCtrl.stream;
  Stream<Map<String, dynamic>> get onPathsInvite    => _pathsInviteCtrl.stream;
  Stream<Map<String, dynamic>> get onFreezeRoomAnswer => _freezeRoomAnswerCtrl.stream;
  Stream<Map<String, dynamic>> get onFreezeRoomReveal => _freezeRoomRevealCtrl.stream;
  Stream<Map<String, dynamic>> get onFreezeRoomClosed => _freezeRoomClosedCtrl.stream;

  bool get isConnected => _connected;

  // ── Connect ──────────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_connected) return;
    _manualDisconnect = false;
    await _doConnect();
  }

  Future<void> _doConnect() async {
    final token = await ApiClient.instance.getAccessToken();
    if (token == null) return;

    // Dispose previous socket cleanly before creating a new one
    _socket?.dispose();
    _socket = null;

    // socket.io built-in reconnection is disabled — we handle it manually
    // so we can refresh the JWT token before each reconnect attempt.
    _socket = io.io(
      _kWsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .disableReconnection()   // manual reconnect with token refresh
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _connected = true;
        _reconnectAttempt = 0;
        _reconnectTimer?.cancel();
        debugPrint('[WS] connected');
      })
      ..onDisconnect((reason) {
        _connected = false;
        debugPrint('[WS] disconnected: $reason');
        if (!_manualDisconnect) {
          _scheduleReconnect();
        }
      })
      ..onConnectError((data) {
        _connected = false;
        debugPrint('[WS] connect error: $data');
        if (!_manualDisconnect) {
          _scheduleReconnect();
        }
      })
      ..on('chat:message', (data) => _chatMessageCtrl.add(_cast(data)))
      ..on('chat:ack',     (data) => _chatAckCtrl.add(_cast(data)))
      ..on('chat:status',  (data) => _chatStatusCtrl.add(_cast(data)))
      ..on('chat:read',    (data) => _chatReadCtrl.add(_cast(data)))
      ..on('chat:error',   (data) => _chatErrorCtrl.add(_cast(data)))
      ..on('match:new',    (data) => _matchNewCtrl.add(_cast(data)))
      ..on('match:removed', (data) => _matchRemovedCtrl.add(_cast(data)))
      ..on('melt:invite',  (data) => _meltInviteCtrl.add(_cast(data)))
      ..on('melt:status',  (data) => _meltStatusCtrl.add(_cast(data)))
      ..on('blind:session_created', (data) => _blindSessionCtrl.add(_cast(data)))
      ..on('blind:phase_change',    (data) => _blindPhaseCtrl.add(_cast(data)))
      ..on('paths:invite', (data) => _pathsInviteCtrl.add(_cast(data)))
      ..on('freeze_room:answer_in', (data) => _freezeRoomAnswerCtrl.add(_cast(data)))
      // Server emits 'freeze_room:reveal_received' (was listening for the wrong
      // name 'freeze_room:reveal', so reveals never reached the client).
      ..on('freeze_room:reveal_received', (data) => _freezeRoomRevealCtrl.add(_cast(data)))
      ..on('freeze_room:closed',    (data) => _freezeRoomClosedCtrl.add(_cast(data)));

    _socket!.connect();
  }

  // Exponential backoff: 2s, 4s, 8s, 16s, 32s, capped at 60s
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    const maxAttempts = 15;
    if (_reconnectAttempt >= maxAttempts) {
      debugPrint('[WS] max reconnect attempts reached');
      return;
    }
    final delaySeconds = (2 << _reconnectAttempt.clamp(0, 5)).clamp(2, 60);
    _reconnectAttempt++;
    debugPrint('[WS] reconnecting in ${delaySeconds}s (attempt $_reconnectAttempt)');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (_manualDisconnect) return;
      // Refresh token before reconnecting — JWT may have expired
      await _refreshTokenIfNeeded();
      await _doConnect();
    });
  }

  Future<void> _refreshTokenIfNeeded() async {
    try {
      final refreshToken = await ApiClient.instance.getRefreshToken();
      if (refreshToken == null) return;
      // ApiClient's _AuthInterceptor handles refresh on 401; here we trigger
      // a lightweight authenticated call to force a refresh if token is stale.
      await ApiClient.instance.dio.get('/health');
    } catch (_) {
      // Ignore — if health fails we still attempt WS connect with existing token
    }
  }

  // ── Disconnect ───────────────────────────────────────────────────────────────

  void disconnect() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
    _reconnectAttempt = 0;
  }

  // ── Emit helpers ─────────────────────────────────────────────────────────────

  void sendChatMessage({
    required String chatId,
    required String text,
    required String clientMsgId,
  }) {
    _emit('chat:send', {'chatId': chatId, 'text': text, 'clientMsgId': clientMsgId});
  }

  void markChatRead({required String chatId, required String messageId}) {
    _emit('chat:read', {'chatId': chatId, 'messageId': messageId});
  }

  void pingPresence() => _emit('presence:ping', {});

  void revealBlind({required String sessionId}) {
    _emit('blind:reveal', {'sessionId': sessionId});
  }

  void joinFreezeRoom(String roomId) {
    _emit('freeze_room:join', {'roomId': roomId});
  }

  void leaveFreezeRoom(String roomId) {
    _emit('freeze_room:leave', {'roomId': roomId});
  }

  // ── Chat message stream for a specific chat ───────────────────────────────────

  Stream<Map<String, dynamic>> chatMessages(String chatId) {
    return onChatMessage.where((event) => event['chatId'] == chatId);
  }

  // ── Private ───────────────────────────────────────────────────────────────────

  void _emit(String event, Map<String, dynamic> data) {
    if (_socket == null || !_connected) {
      debugPrint('[WS] emit ignored — not connected: $event');
      return;
    }
    _socket!.emit(event, data);
  }

  Map<String, dynamic> _cast(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  void dispose() {
    disconnect();
    _chatMessageCtrl.close();
    _chatAckCtrl.close();
    _chatStatusCtrl.close();
    _chatReadCtrl.close();
    _chatErrorCtrl.close();
    _matchNewCtrl.close();
    _matchRemovedCtrl.close();
    _meltInviteCtrl.close();
    _meltStatusCtrl.close();
    _blindSessionCtrl.close();
    _blindPhaseCtrl.close();
    _pathsInviteCtrl.close();
    _freezeRoomAnswerCtrl.close();
    _freezeRoomRevealCtrl.close();
    _freezeRoomClosedCtrl.close();
  }
}
