import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../models/chat_message.dart';
import '../design_system.dart';
import 'freeze_modal.dart' as modal;
import 'typing_indicator.dart';

enum MessageStatus { pending, sent, delivered, read, failed }

class ChatMessageItem {
  ChatMessageItem({
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.status = MessageStatus.sent,
  });

  final String text;
  final bool isMe;
  final String timestamp;
  MessageStatus status;
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
  bool _sending = false;
  bool _simulatedTyping = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _msgSub?.cancel();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    final chatId = AppFlowScope.of(context, listen: false).activeChatId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (text.isEmpty || chatId == null || uid == null || _sending) return;
    _sending = true;
    final now = TimeOfDay.now();
    final message = ChatMessageItem(
      text: text,
      isMe: true,
      timestamp:
          '${now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}',
      status: MessageStatus.pending,
    );
    setState(() {
      _messages.add(message);
    });
    _controller.clear();
    try {
      final flow = AppFlowScope.of(context, listen: false);
      await flow.repository.sendMessage(
        ChatMessage(
          chatId: chatId,
          senderId: uid,
          text: text,
          sentAt: DateTime.now(),
          status: 'sent',
        ),
      );
      setState(() {
        message.status = MessageStatus.sent;
      });

      // Simulate typing response for demo
      if (mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() => _simulatedTyping = true);
            // Scroll to bottom when typing starts
            WidgetsBinding.instance.addPostFrameCallback((_) {
               if (_scrollController.hasClients) {
                 _scrollController.animateTo(
                   _scrollController.position.maxScrollExtent,
                   duration: const Duration(milliseconds: 300),
                   curve: Curves.easeOut,
                 );
               }
            });
          }
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _simulatedTyping = false);
          });
        });
      }

    } catch (_) {
      setState(() {
        message.status = MessageStatus.failed;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send. Please retry.'),
        ),
      );
    } finally {
      _sending = false;
    }
    Future<void>.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
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
                  gradient: FreezmeGradients.primary,
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
                      icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white24,
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white24,
                        backgroundImage: NetworkImage(
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
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Online',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        modal.showFreezeModal(context);
                      },
                      icon: const Icon(Icons.ac_unit, color: Colors.white),
                    ),
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
                        stream: flow.repository.messagesForChat(chatId),
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
                              FirebaseAuth.instance.currentUser?.uid ?? '';
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
                          
                          // Typing logic
                          final showTyping = _simulatedTyping;
                          final itemCount = mapped.length + (showTyping ? 1 : 0);

                          return ListView.builder(
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
}

