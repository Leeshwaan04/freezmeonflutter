import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main.dart';
import '../components/aurora_background.dart';
import '../components/premium_components.dart';
import '../components/skeleton_loaders.dart';

import '../design_system.dart';
import 'message_status.dart';
import '../../models/vibe_profile.dart';

class Conversation {
  Conversation({
    required this.chatId,
    required this.displayName,
    required this.photoUrl,
    required this.lastMessage,
    required this.timeLabel,
    this.unread = 0,
    this.status = MessageStatus.delivered,
    this.isGroup = false,
    this.isPinned = false,
    this.isMuted = false,
    this.isArchived = false,
    this.isOnline = false,
    this.isTyping = false,
    this.expiresAt,
    this.hasConversationStarted = false,
  });

  final String chatId;
  final String displayName;
  final String photoUrl;
  String lastMessage;
  String timeLabel;
  int unread;
  MessageStatus status;
  bool isGroup;
  bool isPinned;
  bool isMuted;
  bool isArchived;
  bool isOnline;
  bool isTyping;
  final DateTime? expiresAt;
  final bool hasConversationStarted;

  bool get isExpired => !hasConversationStarted && expiresAt != null && DateTime.now().isAfter(expiresAt!);
  Duration? get remainingTime => expiresAt?.difference(DateTime.now());
}

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _showUnreadOnly = false;
  List<Conversation> _conversations = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Conversation> _filterConversations(List<Conversation> conversations) {
    return conversations.where((c) {
      final matchesQuery = _query.isEmpty ||
          c.displayName.toLowerCase().contains(_query.toLowerCase()) ||
          c.lastMessage.toLowerCase().contains(_query.toLowerCase());
      final matchesUnread = !_showUnreadOnly || c.unread > 0;
      return matchesQuery && matchesUnread && !c.isArchived;
    }).toList();
  }

  Widget _buildNewMatchesRail(List<Conversation> matches) {
    // Filter for "New" matches - e.g., less than 5 messages or specifically marked
    // For now, allow top 10 matches to appear here for quick access
    final recent = matches.take(10).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(FreezmeDesignSystem.spaceLg, 0, FreezmeDesignSystem.spaceLg, FreezmeDesignSystem.spaceMd),
          child: Text(
            'New Matches',
            style: FreezmeDesignSystem.captionMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: FreezmeDesignSystem.textSecondary,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg),
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: FreezmeDesignSystem.spaceMd),
            itemBuilder: (context, index) {
              final c = recent[index];
              return GestureDetector(
                onTap: () => AppFlowScope.of(context, listen: false).openChatDetail(
                  VibeProfile(
                    uid: c.chatId,
                    id: 0,
                    name: c.displayName,
                    age: 0,
                    imageUrl: c.photoUrl,
                    compatibility: 0,
                    bio: '',
                    distance: '',
                  ),
                  chatId: c.chatId,
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [FreezmeDesignSystem.primary, FreezmeDesignSystem.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: FreezmeDesignSystem.background,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: FreezmeDesignSystem.surfaceAlt,
                              backgroundImage: c.photoUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(c.photoUrl)
                                  : null,
                              child: c.photoUrl.isEmpty
                                  ? const Icon(Icons.person, color: FreezmeDesignSystem.textTertiary)
                                  : null,
                            ),
                          ),
                        ),
                        // Match Expiry Badge
                        if (!c.hasConversationStarted && c.expiresAt != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: -2,
                            child: Center(
                              child: _MeltingBadge(expiresAt: c.expiresAt!),
                            ),
                          ),
                        if (c.isOnline)
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: FreezmeDesignSystem.success,
                                shape: BoxShape.circle,
                                border: Border.all(color: FreezmeDesignSystem.background, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: FreezmeDesignSystem.spaceXs),
                    SizedBox(
                      width: 64,
                      child: Text(
                        c.displayName.split(' ').first,
                        textAlign: TextAlign.center,
                        style: FreezmeDesignSystem.smallMedium.copyWith(
                          color: FreezmeDesignSystem.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: FreezmeDesignSystem.spaceMd),
        const Divider(height: 1, color: FreezmeDesignSystem.border),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        isPremium: flow.isPremium,
        child: SafeArea(
          bottom: false,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: flow.repository.watchMatches(),
            initialData: const [], // Start with empty list so we always have data
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CustomScrollView(
                    slivers: [
                       SliverToBoxAdapter(child: SizedBox(height: 100)), // Approximate header space
                       SliverFillRemaining(child: ChatListSkeleton(itemCount: 8)),
                    ],
                  );
              }

              // Start with the Header as a fixed sliver
              final List<Widget> slivers = [
                SliverToBoxAdapter(child: _buildHeader()),
              ];

              // Handle error state
              if (snapshot.hasError) {
                slivers.add(SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorStateView(
                    message: 'We couldn\'t load your chats.\nPlease check your connection.',
                    onRetry: () => setState(() {}),
                  ),
                ));
              }
              // Handle data state (including empty initial state)
              else {
                final matches = snapshot.data ?? [];
                final mapped = matches.map((m) {
                  final id = m['id']?.toString() ?? '';
                  final displayName = m['name']?.toString() ??
                      (m['otherUserName']?.toString() ?? 'Freezme Match');
                  final photo = m['photoUrl']?.toString() ?? '';
                  final lastMsg = m['lastMessage']?.toString() ?? 'Tap to open chat';
                  final timeLabel = m['timeLabel']?.toString() ?? '';
                  final unread = (m['unread'] as num?)?.toInt() ?? 0;
                  final statusString = m['status']?.toString();
                  final status = parseMessageStatus(statusString);
                  
                  return Conversation(
                    chatId: id,
                    displayName: displayName,
                    photoUrl: photo,
                    lastMessage: lastMsg,
                    timeLabel: timeLabel,
                    unread: unread,
                    status: status,
                    isGroup: (m['isGroup'] as bool?) ?? false,
                    isPinned: (m['isPinned'] as bool?) ?? false,
                    isMuted: (m['isMuted'] as bool?) ?? false,
                    isArchived: (m['isArchived'] as bool?) ?? false,
                    isOnline: (m['isOnline'] as bool?) ?? false,
                    isTyping: (m['isTyping'] as bool?) ?? false,
                    expiresAt: m['expiresAt'] != null ? DateTime.tryParse(m['expiresAt'].toString()) : null,
                    hasConversationStarted: (m['hasConversationStarted'] as bool?) ?? false,
                  );
                }).toList();
                
                mapped.sort((a, b) => (b.isPinned ? 1 : 0) - (a.isPinned ? 1 : 0));
                _conversations = mapped;
                final visibleConversations = _filterConversations(_conversations);

                // Show "New Matches" rail if applicable
                if (visibleConversations.isNotEmpty && !_showUnreadOnly && _query.isEmpty) {
                  slivers.add(SliverToBoxAdapter(child: _buildNewMatchesRail(visibleConversations)));
                }

                // Show "Frozen Connections" rail if applicable
                if (flow.pendingMeltInvites.isNotEmpty && !_showUnreadOnly && _query.isEmpty) {
                  slivers.add(SliverToBoxAdapter(child: _buildFrozenConnections(flow.pendingMeltInvites, flow)));
                  slivers.add(const SliverToBoxAdapter(child: SizedBox(height: FreezmeDesignSystem.spaceLg)));
                }

                if (visibleConversations.isEmpty) {
                  slivers.add(SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateView(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No Matches Yet',
                      subtitle: 'Start exploring to find your perfect match! Your conversations will appear here.',
                      actionLabel: 'Explore Tonight',
                      onAction: () {
                        // Navigate to Tonight tab
                        flow.openTab(0);
                      },
                    ),
                  ));
                } else {
                  slivers.add(SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final convo = visibleConversations[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: FreezmeDesignSystem.spaceMd,
                            vertical: FreezmeDesignSystem.spaceXs,
                          ),
                          decoration: BoxDecoration(
                            color: convo.unread > 0 
                                ? FreezmeDesignSystem.primary.withValues(alpha: 0.03)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusMd),
                            border: Border.all(
                              color: convo.unread > 0 
                                  ? FreezmeDesignSystem.primary.withValues(alpha: 0.15)
                                  : FreezmeDesignSystem.border.withValues(alpha: 0.5),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(FreezmeDesignSystem.radiusMd),
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                flow.openChatDetail(
                                  VibeProfile(
                                    uid: convo.chatId,
                                    id: 0,
                                    name: convo.displayName,
                                    age: 0,
                                    imageUrl: convo.photoUrl,
                                    compatibility: 0,
                                    bio: '',
                                    distance: '',
                                  ),
                                  chatId: convo.chatId,
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(FreezmeDesignSystem.spaceMd),
                                child: Row(
                                  children: [
                                    // Avatar with gradient border for unread
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: convo.unread > 0 
                                            ? FreezmeGradients.header
                                            : null,
                                        border: convo.unread == 0 
                                            ? Border.all(color: FreezmeDesignSystem.border, width: 1)
                                            : null,
                                      ),
                                      child: CircleAvatar(
                                        radius: 26,
                                        backgroundColor: FreezmeDesignSystem.surfaceAlt,
                                        backgroundImage: convo.photoUrl.isNotEmpty
                                            ? CachedNetworkImageProvider(convo.photoUrl)
                                            : null,
                                        child: convo.photoUrl.isEmpty
                                            ? const Icon(Icons.person, color: FreezmeDesignSystem.textTertiary)
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: FreezmeDesignSystem.spaceMd),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  convo.displayName,
                                                  style: FreezmeDesignSystem.bodyMedium.copyWith(
                                                    fontWeight: convo.unread > 0 ? FontWeight.w700 : FontWeight.w600,
                                                    color: FreezmeDesignSystem.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: convo.unread > 0 
                                                      ? FreezmeDesignSystem.primary.withValues(alpha: 0.1)
                                                      : Colors.transparent,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  convo.timeLabel,
                                                  style: FreezmeDesignSystem.small.copyWith(
                                                    color: convo.unread > 0 ? FreezmeDesignSystem.primary : FreezmeDesignSystem.textTertiary,
                                                    fontWeight: convo.unread > 0 ? FontWeight.w600 : FontWeight.normal,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              if (convo.status == MessageStatus.read)
                                                Padding(
                                                  padding: const EdgeInsets.only(right: 4),
                                                  child: Icon(
                                                    Icons.done_all,
                                                    size: 14,
                                                    color: FreezmeDesignSystem.primary.withValues(alpha: 0.7),
                                                  ),
                                                ),
                                              if (convo.isTyping)
                                                Container(
                                                  margin: const EdgeInsets.only(right: 4),
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: FreezmeDesignSystem.success.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Text(
                                                    'typing...',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: FreezmeDesignSystem.success,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                )
                                              else
                                                Expanded(
                                                  child: Text(
                                                    convo.lastMessage,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: FreezmeDesignSystem.caption.copyWith(
                                                      color: convo.unread > 0 
                                                          ? FreezmeDesignSystem.textPrimary 
                                                          : FreezmeDesignSystem.textSecondary,
                                                      fontWeight: convo.unread > 0 ? FontWeight.w500 : FontWeight.normal,
                                                    ),
                                                  ),
                                                ),
                                              if (convo.isPinned)
                                                Padding(
                                                  padding: const EdgeInsets.only(left: 8),
                                                  child: Icon(
                                                    Icons.push_pin_rounded,
                                                    size: 14,
                                                    color: FreezmeDesignSystem.primary.withValues(alpha: 0.5),
                                                  ),
                                                ),
                                              if (convo.unread > 0)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 8),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    gradient: const LinearGradient(
                                                      colors: [FreezmeDesignSystem.primary, FreezmeDesignSystem.secondary],
                                                    ),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    '${convo.unread}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: visibleConversations.length,
                    ),
                  ));
                }
              }

              slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 100)));

              return CustomScrollView(
                slivers: slivers,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg, vertical: FreezmeDesignSystem.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Chats', style: FreezmeDesignSystem.h1),
              IconButton(
                icon: const Icon(Icons.edit_square, color: FreezmeDesignSystem.primary),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: FreezmeDesignSystem.spaceMd),
          PremiumTextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            hintText: 'Search chats...',
            prefixIcon: Icons.search,
          ),
           const SizedBox(height: FreezmeDesignSystem.spaceMd),
           SingleChildScrollView(
             scrollDirection: Axis.horizontal,
             child: Row(
              children: [
                 PremiumChip(
                  label: 'All', 
                  selected: !_showUnreadOnly,
                  onTap: () => setState(() => _showUnreadOnly = false),
                ),
                const SizedBox(width: FreezmeDesignSystem.spaceSm),
                PremiumChip(
                  label: 'Unread', 
                  selected: _showUnreadOnly,
                  onTap: () => setState(() => _showUnreadOnly = true),
                ),
              ],
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildFrozenConnections(List<Map<String, dynamic>> invites, AppFlowController flow) {
    if (invites.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(FreezmeDesignSystem.spaceLg, FreezmeDesignSystem.spaceLg, FreezmeDesignSystem.spaceLg, FreezmeDesignSystem.spaceMd),
          child: Row(
            children: [
              const Icon(Icons.ac_unit, color: FreezmeDesignSystem.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Frozen Connections',
                style: FreezmeDesignSystem.captionMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: FreezmeDesignSystem.secondary,
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: FreezmeDesignSystem.spaceLg),
          itemCount: invites.length,
          separatorBuilder: (_, _) => const SizedBox(height: FreezmeDesignSystem.spaceMd),
          itemBuilder: (context, index) {
            final invite = invites[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: FreezmeDesignSystem.cardDecorationFlat,
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: FreezmeDesignSystem.surfaceAlt,
                    child: Icon(Icons.person, color: FreezmeDesignSystem.textTertiary),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Secret Admirer', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Sent you a ice melter!', style: FreezmeDesignSystem.small),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => flow.meltChatService.respondInvite(inviteId: invite['id'], action: 'decline'),
                        icon: const Icon(Icons.close, color: FreezmeDesignSystem.error, size: 20),
                      ),
                      IconButton(
                        onPressed: () => flow.meltChatService.respondInvite(inviteId: invite['id'], action: 'accept'),
                        icon: const Icon(Icons.favorite, color: FreezmeDesignSystem.secondary, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _MeltingBadge extends StatelessWidget {
  final DateTime expiresAt;
  const _MeltingBadge({required this.expiresAt});

  @override
  Widget build(BuildContext context) {
    final remaining = expiresAt.difference(DateTime.now());
    final hours = remaining.inHours;

    Color badgeColor;
    if (hours > 24) {
      badgeColor = Colors.blueAccent;
    } else if (hours > 6) {
      badgeColor = Colors.orangeAccent;
    } else {
      badgeColor = Colors.redAccent;
    }

    final label = hours > 0 ? '${hours}h' : '${remaining.inMinutes}m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hours <= 6 ? Icons.whatshot : Icons.timer,
            color: Colors.white,
            size: 8,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
