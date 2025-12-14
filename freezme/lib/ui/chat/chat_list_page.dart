import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../shared/bottom_nav_bar.dart';
import '../../main.dart';
import '../../ui/theme.dart';
import '../shared/state_views.dart';


enum _MessageStatus { pending, sent, delivered, read, failed }

// Skeleton loading widget for better perceived performance
class _SkeletonChatItem extends StatelessWidget {
  const _SkeletonChatItem();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 200,
                    decoration: BoxDecoration(
                      color:Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 12,
              width: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Conversation {
  Conversation({
    required this.chatId,
    required this.displayName,
    required this.photoUrl,
    required this.lastMessage,
    required this.timeLabel,
    this.unread = 0,
    this.status = _MessageStatus.delivered,
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
  _MessageStatus status;
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

  IconData _statusIcon(_MessageStatus status) {
    switch (status) {
      case _MessageStatus.pending:
        return Icons.access_time;
      case _MessageStatus.sent:
        return Icons.check;
      case _MessageStatus.delivered:
        return Icons.done_all;
      case _MessageStatus.read:
        return Icons.done_all;
      case _MessageStatus.failed:
        return Icons.error_outline;
    }
  }

  Widget _buildNewMatchesRail(List<Conversation> matches) {
    // Filter for "New" matches - e.g., less than 5 messages or specifically marked
    // For now, allow top 10 matches to appear here for quick access
    final recent = matches.take(10).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text(
            'New Matches',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: FreezmeColors.neutral,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: recent.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
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
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [FreezmeColors.primary, FreezmeColors.secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: FreezmeColors.surfaceAlt,
                              backgroundImage: c.photoUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(c.photoUrl)
                                  : null,
                              child: c.photoUrl.isEmpty
                                  ? const Icon(Icons.person, color: FreezmeColors.muted)
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
                                color: FreezmeColors.success,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 64,
                      child: Text(
                        c.displayName.split(' ').first,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FreezmeColors.neutral,
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
        const SizedBox(height: 16),
        const Divider(height: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: true);

    return Scaffold(
      bottomNavigationBar: FreezmeBottomNavBar(
          currentIndex: flow.currentTabIndex,
          onTap: (index) {
            if (_tabLocked) return;
            setState(() => _tabLocked = true);
            flow.openTab(index);
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => _tabLocked = false);
            });
          },
      ),
      body: Container(
        color: Colors.white,
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
                slivers.add(SliverToBoxAdapter(child: _buildSkeletonLoader()));
              }
              // Handle error state
              else if (snapshot.hasError) {
                slivers.add(SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorView(),
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
                  final status = switch (statusString) {
                    'read' => _MessageStatus.read,
                    'sent' => _MessageStatus.sent,
                    _ => _MessageStatus.delivered,
                  };
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
                  slivers.add(SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyView(),
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
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: FreezmeColors.surfaceAlt,
                                      backgroundImage: convo.photoUrl.isNotEmpty
                                          ? CachedNetworkImageProvider(convo.photoUrl)
                                          : null,
                                      child: convo.photoUrl.isEmpty
                                          ? const Icon(Icons.person, color: FreezmeColors.muted)
                                          : null,
                                    ),
                                    if (convo.unread > 0)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: FreezmeColors.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            convo.displayName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: convo.unread > 0 ? FontWeight.w700 : FontWeight.w600,
                                              color: FreezmeColors.neutral,
                                            ),
                                          ),
                                          Text(
                                            convo.timeLabel,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: convo.unread > 0 ? FreezmeColors.primary : FreezmeColors.muted,
                                              fontWeight: convo.unread > 0 ? FontWeight.w600 : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (convo.status == _MessageStatus.read)
                                              const Padding(
                                                padding: EdgeInsets.only(right: 4),
                                                child: Icon(Icons.done_all, size: 16, color: FreezmeColors.primary),
                                              ),
                                          Expanded(
                                            child: Text(
                                              convo.lastMessage,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: convo.unread > 0 ? FreezmeColors.neutral : FreezmeColors.muted,
                                                fontWeight: convo.unread > 0 ? FontWeight.w500 : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          if (convo.isPinned)
                                              const Icon(Icons.push_pin, size: 14, color: FreezmeColors.muted),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Chats', style: FreezmeTypography.display),
              IconButton(
                icon: const Icon(Icons.edit_square, color: FreezmeColors.primary),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Search chats...',
              prefixIcon: const Icon(Icons.search, color: FreezmeColors.muted),
              filled: true,
              fillColor: FreezmeColors.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
           const SizedBox(height: 16),
           SingleChildScrollView(
             scrollDirection: Axis.horizontal,
             child: Row(
              children: [
                 FilterChip(
                  label: const Text('All'), 
                  selected: !_showUnreadOnly,
                  onSelected: (v) => setState(() => _showUnreadOnly = false),
                  backgroundColor: Colors.transparent,
                  selectedColor: FreezmeColors.primary.withValues(alpha: 0.1),
                  side: BorderSide(
                    color: !_showUnreadOnly ? FreezmeColors.primary : FreezmeColors.border,
                  ),
                  labelStyle: TextStyle(
                    color: !_showUnreadOnly ? FreezmeColors.primary : FreezmeColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Unread'), 
                  selected: _showUnreadOnly,
                  onSelected: (v) => setState(() => _showUnreadOnly = true),
                   backgroundColor: Colors.transparent,
                  selectedColor: FreezmeColors.primary.withValues(alpha: 0.1),
                  side: BorderSide(
                    color: _showUnreadOnly ? FreezmeColors.primary : FreezmeColors.border,
                  ),
                  labelStyle: TextStyle(
                    color: _showUnreadOnly ? FreezmeColors.primary : FreezmeColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ],
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
     return ListView.separated(
       padding: const EdgeInsets.symmetric(horizontal: 20),
       shrinkWrap: true,
       physics: const NeverScrollableScrollPhysics(),
       itemCount: 6,
       separatorBuilder: (_, __) => const SizedBox(height: 24),
       itemBuilder: (_, __) => Row(
         children: [
           Container(
             width: 56, height: 56,
             decoration: BoxDecoration(
               color: FreezmeColors.surfaceAlt,
               shape: BoxShape.circle,
             ),
           ),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Container(width: 120, height: 16, decoration: BoxDecoration(color: FreezmeColors.surfaceAlt, borderRadius: BorderRadius.circular(4))),
                 const SizedBox(height: 8),
                 Container(width: double.infinity, height: 12, decoration: BoxDecoration(color: FreezmeColors.surfaceAlt, borderRadius: BorderRadius.circular(4))),
               ],
             ),
           ),
         ],
       ),
     );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: FreezmeColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_off_rounded, size: 48, color: FreezmeColors.muted),
          ),
          const SizedBox(height: 24),
          const Text('Connection Issue', style: FreezmeTypography.title),
          const SizedBox(height: 8),
          const Text(
            'We couldn\'t load your chats.\nPlease check your connection and try again.',
            textAlign: TextAlign.center,
            style: FreezmeTypography.bodyMuted,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FreezmeColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: FreezmeColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline, size: 48, color: FreezmeColors.muted),
          ),
           const SizedBox(height: 16),
           const Text(
             'No conversations found',
             style: TextStyle(
               fontSize: 18,
               fontWeight: FontWeight.w600,
               color: FreezmeColors.neutral,
             ),
           ),
           const SizedBox(height: 8),
           const Text(
             'Try adjusting your filters or say hi to someone new!',
             textAlign: TextAlign.center,
             style: FreezmeTypography.bodyMuted,
           ),
        ],
      ),
    );
  }
}

class _ProfileGate extends StatelessWidget {
  const _ProfileGate({required this.flow});
  final AppFlowController flow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: FreezmeGradients.backgroundSoft,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: FreezmeColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.lock_outline,
                          color: FreezmeColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Complete your profile to chat',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${flow.completionPercent}% complete · add photos, bio, preferences',
                            style: const TextStyle(
                              fontSize: 12,
                              color: FreezmeColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => AppFlowScope.of(context, listen: false)
                        .replaceStack(<AppStage>[AppStage.profileCompletion]),
                    style: FilledButton.styleFrom(
                      backgroundColor: FreezmeColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Complete profile',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _SkeletonChatCard extends StatefulWidget {
  @override
  State<_SkeletonChatCard> createState() => _SkeletonChatCardState();
}

class _SkeletonChatCardState extends State<_SkeletonChatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Avatar skeleton
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        FreezmeColors.border,
                        FreezmeColors.border.withValues(alpha: 0.5),
                        FreezmeColors.border,
                      ],
                      stops: [
                        _animation.value - 0.3,
                        _animation.value,
                        _animation.value + 0.3,
                      ].map((e) => e.clamp(0.0, 1.0)).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name skeleton
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              FreezmeColors.border,
                              FreezmeColors.border.withValues(alpha: 0.5),
                              FreezmeColors.border,
                            ],
                            stops: [
                              _animation.value - 0.3,
                              _animation.value,
                              _animation.value + 0.3,
                            ].map((e) => e.clamp(0.0, 1.0)).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Message skeleton
                      Container(
                        height: 14,
                        width: MediaQuery.of(context).size.width * 0.6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              FreezmeColors.border,
                              FreezmeColors.border.withValues(alpha: 0.5),
                              FreezmeColors.border,
                            ],
                            stops: [
                              _animation.value - 0.3,
                              _animation.value,
                              _animation.value + 0.3,
                            ].map((e) => e.clamp(0.0, 1.0)).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Time skeleton
                    Container(
                      height: 12,
                      width: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            FreezmeColors.border,
                            FreezmeColors.border.withValues(alpha: 0.5),
                            FreezmeColors.border,
                          ],
                          stops: [
                            _animation.value - 0.3,
                            _animation.value,
                            _animation.value + 0.3,
                          ].map((e) => e.clamp(0.0, 1.0)).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Status icon skeleton
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            FreezmeColors.border,
                            FreezmeColors.border.withValues(alpha: 0.5),
                            FreezmeColors.border,
                          ],
                          stops: [
                            _animation.value - 0.3,
                            _animation.value,
                            _animation.value + 0.3,
                          ].map((e) => e.clamp(0.0, 1.0)).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

