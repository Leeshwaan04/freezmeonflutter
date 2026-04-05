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

  // Per-event stream controllers
  final _chatMessageCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _chatReadCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _matchNewCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _meltInviteCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _meltStatusCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _blindSessionCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _blindPhaseCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _pathsInviteCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _freezeRoomAnswerCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _freezeRoomRevealCtrl = StreamController<Map<String, dynamic>>.broadcast();
  final _freezeRoomClosedCtrl = StreamController<Map<String, dynamic>>.broadcast();

  // ── Exposed streams ──────────────────────────────────────────────────────────
  Stream<Map<String, dynamic>> get onChatMessage => _chatMessageCtrl.stream;
  Stream<Map<String, dynamic>> get onChatRead => _chatReadCtrl.stream;
  Stream<Map<String, dynamic>> get onMatchNew => _matchNewCtrl.stream;
  Stream<Map<String, dynamic>> get onMeltInvite => _meltInviteCtrl.stream;
  Stream<Map<String, dynamic>> get onMeltStatus => _meltStatusCtrl.stream;
  Stream<Map<String, dynamic>> get onBlindSession => _blindSessionCtrl.stream;
  Stream<Map<String, dynamic>> get onBlindPhase => _blindPhaseCtrl.stream;
  Stream<Map<String, dynamic>> get onPathsInvite => _pathsInviteCtrl.stream;
  Stream<Map<String, dynamic>> get onFreezeRoomAnswer => _freezeRoomAnswerCtrl.stream;
  Stream<Map<String, dynamic>> get onFreezeRoomReveal => _freezeRoomRevealCtrl.stream;
  Stream<Map<String, dynamic>> get onFreezeRoomClosed => _freezeRoomClosedCtrl.stream;

  bool get isConnected => _connected;

  // ── Connect ──────────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_connected) return;
    final token = await ApiClient.instance.getAccessToken();
    if (token == null) return;

    _socket = io.io(
      _kWsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _connected = true;
        debugPrint('[WS] connected');
      })
      ..onDisconnect((_) {
        _connected = false;
        debugPrint('[WS] disconnected');
      })
      ..onConnectError((data) => debugPrint('[WS] connect error: $data'))
      ..on('chat:message', (data) => _chatMessageCtrl.add(_cast(data)))
      ..on('chat:read', (data) => _chatReadCtrl.add(_cast(data)))
      ..on('match:new', (data) => _matchNewCtrl.add(_cast(data)))
      ..on('melt:invite', (data) => _meltInviteCtrl.add(_cast(data)))
      ..on('melt:status', (data) => _meltStatusCtrl.add(_cast(data)))
      ..on('blind:session_created', (data) => _blindSessionCtrl.add(_cast(data)))
      ..on('blind:phase_change', (data) => _blindPhaseCtrl.add(_cast(data)))
      ..on('paths:invite', (data) => _pathsInviteCtrl.add(_cast(data)))
      ..on('freeze_room:answer_in', (data) => _freezeRoomAnswerCtrl.add(_cast(data)))
      ..on('freeze_room:reveal', (data) => _freezeRoomRevealCtrl.add(_cast(data)))
      ..on('freeze_room:closed', (data) => _freezeRoomClosedCtrl.add(_cast(data)));
  }

  // ── Disconnect ───────────────────────────────────────────────────────────────

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
  }

  // ── Emit helpers ─────────────────────────────────────────────────────────────

  void sendChatMessage({required String chatId, required String text}) {
    _emit('chat:send', {'chatId': chatId, 'text': text});
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
    _chatReadCtrl.close();
    _matchNewCtrl.close();
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
