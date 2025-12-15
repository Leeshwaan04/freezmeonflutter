import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../shared/bottom_nav_bar.dart';
import '../../main.dart';
import '../components/premium_components.dart';
import '../components/skeleton_loaders.dart';
import '../design_system.dart';
import 'message_status.dart';
import '../../models/vibe_profile.dart'; // Added

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
  bool _tabLocked = false;

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
            separatorBuilder: (_, __) => const SizedBox(width: FreezmeDesignSystem.spaceMd),
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
    final flow = AppFlowScope.of(context, listen: true);

    return Scaffold(
      backgroundColor: FreezmeDesignSystem.background,
      bottomNavigationBar: FreezmeBottomNavBar(
          currentIndex: flow.currentTabIndex,
          onTap: (index) {
            if (_tabLocked) return;
            setState(() => _tabLocked = true);
            flow.openTab(index);
            Future.delayed(FreezmeDesignSystem.durationNormal, () {
              if (mounted) setState(() => _tabLocked = false);
            });
          },
      ),
      body: Container(
        color: FreezmeDesignSystem.background,
        child: SafeArea(
          bottom: false,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: flow.repository.watchMatches(),
            builder: (context, snapshot) {
              // Start with the Header as a fixed sliver
              final List<Widget> slivers = [
                SliverToBoxAdapter(child: _buildHeader()),
              ];

              // Handle loading state
              if (snapshot.connectionState == ConnectionState.waiting) {
                slivers.add(const SliverToBoxAdapter(child: ChatListSkeleton(itemCount: 6)));
              }
              // Handle error state
              else if (snapshot.hasError) {
                slivers.add(SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorStateView(
                    message: 'We couldn\'t load your chats.\nPlease check your connection.',
                    onRetry: () => setState(() {}),
                  ),
                ));
              }
              // Handle data state
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
                  );
                }).toList();
                
                mapped.sort((a, b) => (b.isPinned ? 1 : 0) - (a.isPinned ? 1 : 0));
                _conversations = mapped;
                final visibleConversations = _filterConversations(_conversations);

                // Show "New Matches" rail if applicable
                if (visibleConversations.isNotEmpty && !_showUnreadOnly && _query.isEmpty) {
                  slivers.add(SliverToBoxAdapter(child: _buildNewMatchesRail(visibleConversations)));
                }

                if (visibleConversations.isEmpty) {
                  slivers.add(const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateView(
                      icon: Icons.chat_bubble_outline,
                      title: 'No conversations found',
                      subtitle: 'Try adjusting your filters or say hi to someone new!',
                    ),
                  ));
                } else {
                  slivers.add(SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final convo = visibleConversations[index];
                        return InkWell(
                          onTap: () {
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: FreezmeDesignSystem.spaceLg,
                              vertical: FreezmeDesignSystem.spaceMd
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: FreezmeDesignSystem.surfaceAlt,
                                      backgroundImage: convo.photoUrl.isNotEmpty
                                          ? CachedNetworkImageProvider(convo.photoUrl)
                                          : null,
                                      child: convo.photoUrl.isEmpty
                                          ? const Icon(Icons.person, color: FreezmeDesignSystem.textTertiary)
                                          : null,
                                    ),
                                    if (convo.unread > 0)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: FreezmeDesignSystem.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: FreezmeDesignSystem.background, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: FreezmeDesignSystem.spaceMd),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            convo.displayName,
                                            style: FreezmeDesignSystem.bodyMedium.copyWith(
                                              fontWeight: convo.unread > 0 ? FontWeight.w700 : FontWeight.w600,
                                              color: FreezmeDesignSystem.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            convo.timeLabel,
                                            style: FreezmeDesignSystem.small.copyWith(
                                              color: convo.unread > 0 ? FreezmeDesignSystem.primary : FreezmeDesignSystem.textSecondary,
                                              fontWeight: convo.unread > 0 ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: FreezmeDesignSystem.spaceXs),
                                      Row(
                                        children: [
                                          if (convo.status == MessageStatus.read)
                                              const Padding(
                                                padding: EdgeInsets.only(right: 4),
                                                child: Icon(Icons.done_all, size: 16, color: FreezmeDesignSystem.primary),
                                              ),
                                          Expanded(
                                            child: Text(
                                              convo.lastMessage,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: FreezmeDesignSystem.caption.copyWith(
                                                color: convo.unread > 0 ? FreezmeDesignSystem.textPrimary : FreezmeDesignSystem.textSecondary,
                                                fontWeight: convo.unread > 0 ? FontWeight.w500 : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          if (convo.isPinned)
                                              const Icon(Icons.push_pin, size: 14, color: FreezmeDesignSystem.textTertiary),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
}
