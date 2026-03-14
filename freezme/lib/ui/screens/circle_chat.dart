import 'package:flutter/material.dart';
import '../theme.dart';
import '../../controllers/flow_controller.dart';
import '../../models/profile.dart';
import '../widgets/meetup_planner.dart';

class CircleChatPage extends StatefulWidget {
  const CircleChatPage({super.key});

  @override
  State<CircleChatPage> createState() => _CircleChatPageState();
}

class _CircleChatPageState extends State<CircleChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);
    final circle = flow.activeCircle;
    final missionTheme = MissionTheme.fromArchetype(flow.selectedArchetype);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: Column(
          children: [
            _buildPremiumHeader(context, flow, circle, missionTheme),
            _buildMindsetHUD(context, flow),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  _buildSystemMessage('The "Social Escape" has begun! 🏔️'),
                  _buildChatMessage('them', 'Arjun', 'Ready for the morning session at Nitro Brews? 🏋️', true),
                  _buildChatMessage('them', 'Sarah', 'I\'m bringing extra yoga mats! Who else is coming?', false),
                  _buildChatMessage('me', 'You', 'I\'ll be there by 8:15! ✨', false),
                ],
              ),
            ),
            _buildFrostedInput(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context, AppFlowController flow, VibeCircle? circle, MissionTheme theme) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 16),
      decoration: BoxDecoration(
        color: theme.accentColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: theme.accentColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: flow.exitCircleChat,
                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        circle?.name ?? 'Group Escape',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        '${(circle?.members.length ?? 0) + 4} vibing nearby',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => showMeetupPlanner(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white24,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.map_rounded, color: Colors.white),
                  tooltip: 'Plan Meetup',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMindsetHUD(BuildContext context, AppFlowController flow) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _buildMindsetAvatar('🏋️', 'Arjun'),
          _buildMindsetAvatar('🎒', 'Sarah'),
          _buildMindsetAvatar('🥂', 'Priya'),
          _buildMindsetAvatar('🏠', 'Amit'),
          _buildMindsetAvatar('🎶', 'Jess'),
        ],
      ),
    );
  }

  Widget _buildMindsetAvatar(String emoji, String name) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white24,
            child: Text(emoji, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(String text) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildChatMessage(String sender, String name, String text, bool isFirst) {
    bool isMe = sender == 'me';
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe && isFirst)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                name,
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              gradient: isMe ? FreezmeGradients.primary : null,
              color: isMe ? null : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(24),
                topRight: const Radius.circular(24),
                bottomLeft: Radius.circular(isMe ? 24 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 24),
              ),
              border: isMe ? null : Border.all(color: Colors.white12),
            ),
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrostedInput(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Message social circle...',
                  hintStyle: TextStyle(color: Colors.white30),
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
