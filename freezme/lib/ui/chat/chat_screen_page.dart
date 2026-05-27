import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../main.dart';
import '../../models/chat_message.dart';
import '../../services/auth_service.dart';
import '../../services/websocket_service.dart';
import '../../models/conversation_energy.dart';
import '../design_system.dart';
import 'freeze_modal.dart' as modal;
import 'typing_indicator.dart';

enum MessageStatus { pending, sent, delivered, read, failed }

const _uuid = Uuid();

class ChatMessageItem {
  ChatMessageItem({
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.clientMsgId,
    this.serverId,
  });

  final String text;
  final bool isMe;
  final String timestamp;
  MessageStatus status;
  final String? clientMsgId; // local UUID for dedup before server ack
  String? serverId;          // server-assigned message ID after ack
}

IconData _statusIcon(MessageStatus status) {
  switch (status) {
    case MessageStatus.pending:
      return Icons.access_time;
    case MessageStatus.sent:
      return Icons.check;
    case MessageStatus.delivered:
      return Icons.done_all;
    case MessageStatus.read:
      return Icons.done_all;
    case MessageStatus.failed:
      return Icons.error_outline;
  }
}

class ChatScreenPage extends StatefulWidget {
  const ChatScreenPage({super.key});

  @override
  State<ChatScreenPage> createState() => _ChatScreenPageState();
}

class _ChatScreenPageState extends State<ChatScreenPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessageItem> _messages = <ChatMessageItem>[];
  StreamSubscription<List<ChatMessage>>? _msgSub;
  StreamSubscription<Map<String, dynamic>>? _ackSub;
  StreamSubscription<Map<String, dynamic>>? _statusSub;
  Stream<List<ChatMessage>>? _messagesStream;
  String? _messagesStreamChatId;
  bool _sending = false;
  final bool _simulatedTyping = false;

  // Dedup: track server IDs already shown to avoid double-display from HTTP + WS
  final Set<String> _shownServerIds = {};

  // Milestone tracking — celebrate first message and 10-message mark once each.
  final Set<int> _celebratedMilestones = {};
  ConversationEnergy? _latestEnergy;

  static const _milestones = {
    1: '💬 First message sent!',
    10: '🔥 10 messages! The conversation is alive.',
  };

  @override
  void initState() {
    super.initState();
    // Listen for server ACKs to update local message status
    _ackSub = WebSocketService.instance.onChatAck.listen(_handleAck);
    _statusSub = WebSocketService.instance.onChatStatus.listen(_handleStatusUpdate);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _msgSub?.cancel();
    _ackSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  void _handleAck(Map<String, dynamic> event) {
    final clientMsgId = event['clientMsgId'] as String?;
    final serverId = event['messageId'] as String?;
    final status = event['status'] as String?;
    if (clientMsgId == null || !mounted) return;
    setState(() {
      for (final msg in _messages) {
        if (msg.clientMsgId == clientMsgId) {
          msg.serverId = serverId;
          if (serverId != null) _shownServerIds.add(serverId);
          msg.status = _parseStatus(status ?? 'sent');
          break;
        }
      }
    });
  }

  void _handleStatusUpdate(Map<String, dynamic> event) {
    final messageId = event['messageId'] as String?;
    final status = event['status'] as String?;
    if (messageId == null || !mounted) return;
    setState(() {
      for (final msg in _messages) {
        if (msg.serverId == messageId) {
          msg.status = _parseStatus(status ?? 'sent');
          break;
        }
      }
    });
  }

  MessageStatus _parseStatus(String s) {
    switch (s) {
      case 'delivered': return MessageStatus.delivered;
      case 'read':      return MessageStatus.read;
      case 'failed':    return MessageStatus.failed;
      default:          return MessageStatus.sent;
    }
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    final flow = AppFlowScope.of(context, listen: false);
    final chatId = flow.activeChatId;
    final uid = flow.currentUserId;
    if (text.isEmpty || chatId == null || uid == null || _sending) return;
    _sending = true;
    final clientMsgId = _uuid.v4();
    final now = TimeOfDay.now();
    final message = ChatMessageItem(
      text: text,
      isMe: true,
      timestamp:
          '${now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}',
      status: MessageStatus.pending,
      clientMsgId: clientMsgId,
    );
    setState(() { _messages.add(message); });
    _controller.clear();
    _scrollToBottom();

    try {
      await flow.repository.sendMessage(
        ChatMessage(
          chatId: chatId,
          senderId: uid,
          text: text,
          sentAt: DateTime.now(),
          status: 'sent',
          clientMsgId: clientMsgId,
        ),
      );
      if (!mounted) return;
      // Status will be updated by _handleAck when server confirms
      setState(() { message.status = MessageStatus.sent; });
    } catch (_) {
      if (!mounted) return;
      setState(() { message.status = MessageStatus.failed; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not send. Tap to retry.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () {
              setState(() { _messages.remove(message); });
              _controller.text = text;
            },
          ),
        ),
      );
    } finally {
      _sending = false;
    }
  }

  void _scrollToBottom() {
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showHealthSheet(BuildContext context, ConversationEnergy energy) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _ConversationHealthSheet(energy: energy),
    );
  }

  Stream<List<ChatMessage>> _chatStreamFor(dynamic flow, String chatId) {
    if (_messagesStreamChatId != chatId) {
      _messagesStreamChatId = chatId;
      _messagesStream = flow.repository.messagesForChat(chatId);
    }
    return _messagesStream!;
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    final profile = flow.activeProfile;
    final chatId = flow.activeChatId;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: flow.exitChat,
                      icon: const Icon(Icons.chevron_left, color: FreezmeDesignSystem.primary, size: 28),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: FreezmeDesignSystem.primary.withValues(alpha: 0.1),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: FreezmeDesignSystem.surfaceAlt,
                        backgroundImage: CachedNetworkImageProvider(
                          profile?.imageUrl ??
                              'https://images.unsplash.com/photo-1546961329-78bef0414d7c?fit=crop&w=320',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.name ?? 'Match',
                            style: FreezmeDesignSystem.h3.copyWith(
                              color: FreezmeDesignSystem.textPrimary,
                            ),
                          ),
                          if (profile?.dna?.highlights != null && profile!.dna!.highlights!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                profile.dna!.highlights!.first,
                                style: const TextStyle(
                                  color: FreezmeDesignSystem.secondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: _latestEnergy == null
                                ? null
                                : () => _showHealthSheet(context, _latestEnergy!),
                            child: _EnergyChip(messages: _messages),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        modal.showFreezeModal(context);
                      },
                      icon: const Icon(Icons.ac_unit, color: FreezmeDesignSystem.primary),
                    ),
                  ],
                ),
              ),

              // Blind Reveal Action Bar
              if (flow.activeBlindSession != null && flow.activeBlindSession!.phase == 'anonymous')
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: FreezmeDesignSystem.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: FreezmeDesignSystem.primary.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_off_outlined, color: FreezmeDesignSystem.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Blind Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              _getRevealStatusText(flow),
                              style: FreezmeDesignSystem.caption.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (!_hasIVotedReveal(flow))
                        SmallButton(
                          label: 'Reveal',
                          onPressed: () => flow.repository.respondBlindReveal(flow.activeBlindSession!.id),
                        )
                      else
                        const Icon(Icons.check_circle, color: FreezmeDesignSystem.success, size: 20),
                    ],
                  ),
                ),

              // Chat Area
              Expanded(
                child: chatId == null
                    ? Center(
                        child: Text(
                          'No chat selected.',
                          style: FreezmeDesignSystem.body.copyWith(
                            color: FreezmeDesignSystem.textSecondary,
                          ),
                        ),
                      )
                    : StreamBuilder<List<ChatMessage>>(
                        stream: _chatStreamFor(flow, chatId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(color: FreezmeDesignSystem.primary));
                          }
                          if (snapshot.hasError) {
                            return const Center(
                              child: Text('Could not load messages'),
                            );
                          }
                          final msgs = snapshot.data ?? const [];
                          final uid =
                              AuthService.instance.currentUser?.uid ?? '';
                          final mapped = msgs
                              .map(
                                (m) => ChatMessageItem(
                                  text: m.text,
                                  isMe: m.senderId == uid,
                                  timestamp:
                                      DateFormat('h:mm a').format(m.sentAt),
                                  status: switch (m.status) {
                                    'read' => MessageStatus.read,
                                    'delivered' => MessageStatus.delivered,
                                    'sent' => MessageStatus.sent,
                                    _ => MessageStatus.delivered,
                                  },
                                ),
                              )
                              .toList();

                          final energy = ConversationEnergy.compute(mapped);
                          final stage = ConversationEnergy.stageFor(mapped.length);
                          final showPrompts = mapped.length < 9;
                          final showDiscovery =
                              mapped.length >= 8 && mapped.length < 13 &&
                              energy.level == EnergyLevel.medium;
                          final showDateCatalyst =
                              energy.level == EnergyLevel.high && mapped.length >= 10;

                          // Milestone detection — schedule post-frame to avoid
                          // setState during build.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            // Update milestones - only celebrate once
                            _latestEnergy = energy;
                            for (final entry in _milestones.entries) {
                              if (mapped.length >= entry.key &&
                                  !_celebratedMilestones.contains(entry.key)) {
                                _celebratedMilestones.add(entry.key);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(entry.value),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: FreezmeDesignSystem.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              }
                            }
                          });

                          // Typing logic
                          final showTyping = _simulatedTyping;
                          final itemCount = mapped.length + (showTyping ? 1 : 0);

                          return Column(
                            children: [
                              if (showPrompts)
                                _AdaptivePromptStrip(
                                  stage: stage,
                                  interests: flow.activeProfile?.interests ?? const [],
                                  onChipTap: (text) => setState(() => _controller.text = text),
                                ),
                              if (showDiscovery)
                                _SharedDiscoveryCard(
                                  onSend: (text) => setState(() => _controller.text = text),
                                ),
                              if (showDateCatalyst)
                                _DateCatalystBanner(
                                  matchName: flow.activeProfile?.name ?? 'your match',
                                ),
                              Expanded(child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: FreezmeDesignSystem.spaceLg,
                              vertical: FreezmeDesignSystem.spaceLg,
                            ),
                            itemCount: itemCount,
                            itemBuilder: (context, index) {
                              if (showTyping && index == mapped.length) {
                                return const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: EdgeInsets.only(left: 0, top: 4, bottom: 8),
                                    child: TypingIndicator(),
                                  ),
                                );
                              }

                              final msg = mapped[index];
                              final bool isMe = msg.isMe;
                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isMe
                                        ? const LinearGradient(
                                            colors: [
                                              FreezmeDesignSystem.primary,
                                              FreezmeDesignSystem.secondary,
                                            ],
                                          )
                                        : null,
                                    color: isMe ? null : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(20),
                                      topRight: isMe
                                          ? const Radius.circular(4)
                                          : const Radius.circular(20),
                                      bottomLeft: isMe
                                          ? const Radius.circular(20)
                                          : const Radius.circular(4),
                                      bottomRight: const Radius.circular(20),
                                    ),
                                    boxShadow: isMe
                                        ? [
                                            BoxShadow(
                                              color: FreezmeDesignSystem.primary.withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            )
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg.text,
                                        style: FreezmeDesignSystem.body.copyWith(
                                          color: isMe
                                              ? Colors.white
                                              : FreezmeDesignSystem.textPrimary,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            msg.timestamp,
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white70
                                                  : FreezmeDesignSystem.textTertiary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (isMe) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              _statusIcon(msg.status),
                                              size: 12,
                                              color: Colors.white70,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )),
                            ],
                          );
                        },
                      ),
              ),

              // Input Area
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.emoji_emotions_outlined,
                          color: FreezmeDesignSystem.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: FreezmeDesignSystem.surface,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _controller,
                            onSubmitted: (_) => _handleSend(),
                            style: FreezmeDesignSystem.body,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: FreezmeDesignSystem.body.copyWith(
                                color: FreezmeDesignSystem.textTertiary,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Mic icon if text empty, Send if not
                      // _controller logic would be better with setState listener but using simple logic here
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.mic_none,
                          color: FreezmeDesignSystem.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: _handleSend,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            gradient: FreezmeGradients.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  String _getRevealStatusText(AppFlowController flow) {
    final session = flow.activeBlindSession;
    if (session == null) return '';
    final isA = session.userA == AuthService.instance.currentUser?.uid;
    final otherVoted = isA ? session.revealB : session.revealA;
    
    if (otherVoted) return 'They want to reveal! 💜';
    return 'Reveal your vibe when ready.';
  }

  bool _hasIVotedReveal(AppFlowController flow) {
    final session = flow.activeBlindSession;
    if (session == null) return false;
    final isA = session.userA == AuthService.instance.currentUser?.uid;
    return isA ? session.revealA : session.revealB;
  }
}

class SmallButton extends StatelessWidget {
  const SmallButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        backgroundColor: FreezmeDesignSystem.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

// ─── Adaptive Prompt Strip — stage-aware conversation starters ────────────────
class _AdaptivePromptStrip extends StatelessWidget {
  const _AdaptivePromptStrip({
    required this.stage,
    required this.interests,
    required this.onChipTap,
  });

  final ConversationStage stage;
  final List<String> interests;
  final void Function(String) onChipTap;

  // Templates keyed by stage — rotate through per interest.
  static const _templates = {
    ConversationStage.early: [
      'What got you into {interest}?',
      'If you had a full weekend for {interest}, what would you do?',
      "What's the best part of {interest} for you?",
    ],
    ConversationStage.mid: [
      'How did {interest} shape who you are?',
      'Has {interest} ever surprised you?',
      'What would you tell someone just getting into {interest}?',
    ],
    ConversationStage.late: [
      'Where would you take someone to share your love of {interest}?',
      'What does {interest} look like for you on your ideal day?',
      'If we explored {interest} together, where would we start?',
    ],
  };

  static const _fallback = {
    ConversationStage.early: [
      'What do you do for fun? 🎉',
      'Favorite travel spot? ✈️',
      'Morning person or night owl? 🌙',
    ],
    ConversationStage.mid: [
      "What's something you're proud of lately?",
      'Best decision you made this year?',
      'What recharges you after a long week?',
    ],
    ConversationStage.late: [
      'What would your ideal weekend together look like?',
      'If we could be anywhere right now, where?',
      "What's something you've never told anyone on a first date?",
    ],
  };

  static const _headers = {
    ConversationStage.early: 'Break the ice 👋',
    ConversationStage.mid: 'Go deeper 💬',
    ConversationStage.late: 'Imagine together 🌟',
  };

  List<String> _buildPrompts() {
    final templates = _templates[stage]!;
    final List<String> p = [];

    // Prioritize specific DNA highlights for early stage
    if (stage == ConversationStage.early && interests.isNotEmpty) {
      final capped = interests.take(2).toList();
      for (int i = 0; i < capped.length; i++) {
        p.add(templates[i % templates.length].replaceFirst('{interest}', capped[i].toLowerCase()));
      }
      p.add('Explain our compatibility highlights! ✨');
      return p;
    }

    if (interests.isNotEmpty) {
      final capped = interests.take(3).toList();
      return List.generate(capped.length, (i) {
        return templates[i % templates.length]
            .replaceFirst('{interest}', capped[i].toLowerCase());
      });
    }
    return _fallback[stage]!;
  }

  @override
  Widget build(BuildContext context) {
    final prompts = _buildPrompts();
    final header = _headers[stage]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              header,
              style: const TextStyle(
                color: FreezmeDesignSystem.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: prompts.map((prompt) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onChipTap(prompt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: FreezmeDesignSystem.primary.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        prompt,
                        style: const TextStyle(
                          color: FreezmeDesignSystem.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Discovery Card (shown mid-stage, medium energy) ───────────────────
class _SharedDiscoveryCard extends StatelessWidget {
  const _SharedDiscoveryCard({required this.onSend});
  final void Function(String) onSend;

  static const _discoveries = [
    _Discovery('🗺️', 'Travel Style', 'Beach vacation or mountain hiking?'),
    _Discovery('🍳', 'Food Life', 'Cooking at home or trying new restaurants?'),
    _Discovery('🎵', 'Music Mood', "What's your go-to song for a road trip?"),
    _Discovery('📚', 'Free Time', 'Reading a book or watching a series?'),
    _Discovery('🌅', 'Morning Ritual', 'First thing you do when you wake up?'),
  ];

  @override
  Widget build(BuildContext context) {
    final discovery = _discoveries[DateTime.now().minute % _discoveries.length];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FreezmeDesignSystem.primary.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(discovery.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                discovery.title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: FreezmeDesignSystem.primary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              const Text(
                'Discovery',
                style: TextStyle(
                  fontSize: 10,
                  color: FreezmeDesignSystem.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            discovery.prompt,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FreezmeDesignSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => onSend(discovery.prompt),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: FreezmeGradients.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Ask this question',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Discovery {
  const _Discovery(this.emoji, this.title, this.prompt);
  final String emoji;
  final String title;
  final String prompt;
}

// ─── Conversation Health Dashboard (bottom sheet) ─────────────────────────────
class _ConversationHealthSheet extends StatelessWidget {
  const _ConversationHealthSheet({required this.energy});
  final ConversationEnergy energy;

  @override
  Widget build(BuildContext context) {
    final color = Color(energy.colorValue);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Conversation Health', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  energy.label,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            energy.healthSummary,
            style: const TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.4),
          ),
          const SizedBox(height: 24),
          _HealthBar(label: 'Message depth', score: energy.depthScore, color: const Color(0xFF7B2FBE)),
          const SizedBox(height: 12),
          _HealthBar(label: 'Warmth & emoji', score: energy.warmthScore, color: const Color(0xFFFF7043)),
          const SizedBox(height: 12),
          _HealthBar(label: 'Turn balance', score: energy.alternationScore, color: const Color(0xFF42A5F5)),
          const SizedBox(height: 12),
          _HealthBar(label: 'Reply balance', score: energy.reciprocityScore, color: const Color(0xFF26A69A)),
          const SizedBox(height: 24),
          const Text(
            'Tap the energy chip in the header anytime to check back.',
            style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }
}

class _HealthBar extends StatelessWidget {
  const _HealthBar({required this.label, required this.score, required this.color});
  final String label;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
            ),
            Text('$score', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ─── Date Catalyst Banner (shown when energy high + 10+ messages) ─────────────
class _DateCatalystBanner extends StatefulWidget {
  const _DateCatalystBanner({required this.matchName});
  final String matchName;

  @override
  State<_DateCatalystBanner> createState() => _DateCatalystBannerState();
}

class _DateCatalystBannerState extends State<_DateCatalystBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final AnimationController _slideController;
  late final Animation<double> _slideIn;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideIn = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );
    _slideController.forward();

    _glow = Tween<double>(begin: 0.25, end: 0.55).animate(_glowController);
  }

  @override
  void dispose() {
    _glowController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_slideIn, _glow]),
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, 16 * (1 - _slideIn.value)),
          child: Opacity(
            opacity: _slideIn.value.clamp(0.0, 1.0),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7B2FBE), Color(0xFFFF6B6B)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B2FBE).withValues(alpha: _glow.value),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text('✨', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'The vibe is real!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Ready to meet ${widget.matchName} in real life?',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF7B2FBE),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => _SuggestDateDialog(matchName: widget.matchName),
                      );
                    },
                    child: const Text(
                      'Suggest a date',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SuggestDateDialog extends StatelessWidget {
  const _SuggestDateDialog({required this.matchName});
  final String matchName;

  static const _ideas = <String>[
    '☕ Coffee at a local cafe',
    '🎨 Visit a gallery or museum',
    '🌿 Walk in a nearby park',
    '🎬 Catch a movie together',
    '🍕 Dinner at a cozy spot',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Suggest a date with $matchName'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: _ideas
            .map(
              (idea) => ListTile(
                dense: true,
                title: Text(idea, style: const TextStyle(fontSize: 14)),
                onTap: () => Navigator.of(context).pop(),
              ),
            )
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe later'),
        ),
      ],
    );
  }
}

// ─── Conversation Energy Chip ──────────────────────────────────────────────────
// Shown in the chat header below the match's name.
// Re-computes on every build tick so it stays live as messages arrive.
class _EnergyChip extends StatelessWidget {
  const _EnergyChip({required this.messages});

  final List<ChatMessageItem> messages;

  static const _icons = {
    EnergyLevel.low: Icons.battery_1_bar_rounded,
    EnergyLevel.medium: Icons.battery_3_bar_rounded,
    EnergyLevel.high: Icons.bolt_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final energy = ConversationEnergy.compute(messages);
    final color = Color(energy.colorValue);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_icons[energy.level], color: color, size: 13),
        const SizedBox(width: 3),
        Text(
          energy.label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

