import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../../core/app_stage.dart';
import '../widgets/freeze_modal.dart';

class ChatScreenPage extends StatefulWidget {
  const ChatScreenPage({super.key});

  @override
  State<ChatScreenPage> createState() => _ChatScreenPageState();
}

class _ChatScreenPageState extends State<ChatScreenPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = List<Map<String, dynamic>>.from(
    const [
      {
        'text': 'Hey! I saw you are into the same Social Escape! 🏔️',
        'sender': 'them',
        'timestamp': '2:30 PM',
      },
      {
        'text': 'Absolutely! Looking to break my routine. Any plans? ✨',
        'sender': 'me',
        'timestamp': '2:31 PM',
      },
    ],
  );

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final now = TimeOfDay.now();
    setState(() {
      _messages.add({
        'text': text,
        'sender': 'me',
        'timestamp':
            '${now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod}:${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}',
      });
    });
    _controller.clear();
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

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    final profile = flow.activeProfile;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [FreezmeColors.primary, FreezmeColors.secondary],
                  ),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: flow.exitChat,
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(
                        profile?.imageUrl ??
                            'https://images.unsplash.com/photo-1546961329-78bef0414d7c?fit=crop&w=320',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.name ?? 'Match',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Online',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => showFreezeModal(context),
                      icon: const Icon(Icons.ac_unit, color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (profile != null)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.tips_and_updates, color: Colors.white70, size: 16),
                        const SizedBox(width: 12),
                        for (final archetype in profile.archetypes)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  _getArchetypeEmoji(archetype),
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  archetype.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_messages.length <= 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CONTEXTUAL ICEBREAKERS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: FreezmeColors.muted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 48,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: _generateIcebreakers(profile, flow.userBlueprint),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: FreezmeColors.border),
                      ],
                    ),
                  ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final bool isMe = message['sender'] == 'me';
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          gradient: isMe
                              ? const LinearGradient(
                                  colors: [
                                    FreezmeColors.primary,
                                    FreezmeColors.secondary
                                  ],
                                )
                              : null,
                          color: isMe ? null : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(24),
                            topRight: isMe
                                ? const Radius.circular(8)
                                : const Radius.circular(24),
                            bottomLeft: isMe
                                ? const Radius.circular(24)
                                : const Radius.circular(8),
                            bottomRight: const Radius.circular(24),
                          ),
                          boxShadow: isMe
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['text'] as String,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : FreezmeColors.neutral,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              message['timestamp'] as String,
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white70
                                    : FreezmeColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.emoji_emotions_outlined,
                        color: FreezmeColors.primary,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _handleSend(),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          filled: true,
                          fillColor: FreezmeColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.mic_none,
                        color: FreezmeColors.primary,
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _handleSend,
                      style: IconButton.styleFrom(
                        backgroundColor: FreezmeColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getArchetypeEmoji(LifestyleArchetype archetype) {
    switch (archetype) {
      case LifestyleArchetype.gym: return '🏋️';
      case LifestyleArchetype.brunch: return '🥂';
      case LifestyleArchetype.clubbing: return '🎶';
      case LifestyleArchetype.travel: return '🎒';
      case LifestyleArchetype.homebody: return '🏠';
    }
  }

  List<Widget> _generateIcebreakers(dynamic profile, dynamic userBlueprint) {
    final List<Widget> items = [];
    final interests = profile?.interests as List<String>? ?? [];
    
    if (interests.contains('Travel')) {
      items.add(_IcebreakerChip(text: "What destination is on your bucket list? ✈️", onSelected: (val) => _controller.text = val));
    }
    if (interests.contains('Coffee')) {
      items.add(_IcebreakerChip(text: "Best coffee spot in the city? ☕", onSelected: (val) => _controller.text = val));
    }
    
    // Fallback/Generic
    if (items.isEmpty) {
      items.add(_IcebreakerChip(text: "What's something not in your bio? ✨", onSelected: (val) => _controller.text = val));
    }
    
    // Blueprint based
    if (profile?.dna != null && (profile?.dna?.overall ?? 0) > 90) {
      items.add(_IcebreakerChip(text: "We have a ${profile.dna.overall}% match! Destined to chat? 😉", onSelected: (val) => _controller.text = val));
    }

    return items;
  }
}
class _IcebreakerChip extends StatelessWidget {
  final String text;
  final Function(String) onSelected;

  const _IcebreakerChip({required this.text, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(text),
        onPressed: () => onSelected(text),
        backgroundColor: Colors.white,
        shape: StadiumBorder(side: BorderSide(color: FreezmeColors.primary.withValues(alpha: 0.2))),
        labelStyle: const TextStyle(fontSize: 12, color: FreezmeColors.primary),
      ),
    );
  }
}
