import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../ui/theme.dart';


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

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final color = active ? FreezmeColors.primary : FreezmeColors.muted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context, listen: true);

    return Scaffold(
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(
                context,
                icon: Icons.chat_bubble_outline,
                label: 'Chats',
                active: true,
                onTap: () {},
              ),
              _buildNavItem(
                context,
                icon: Icons.favorite_border,
                label: 'Feed',
                active: false,
                onTap: () => flow.openFeed(),
              ),
              _buildNavItem(
                context,
                icon: Icons.route_outlined,
                label: 'Paths',
                active: false,
                onTap: () => flow.openPaths(),
              ),
              _buildNavItem(
                context,
                icon: Icons.bolt_outlined,
                label: 'Blinds',
                active: false,
                onTap: () => flow.openBlinds(),
              ),
              _buildNavItem(
                context,
                icon: Icons.person_outline,
                label: 'Profile',
                active: false,
                onTap: () => flow.openProfileSettings(),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: FreezmeGradients.backgroundSoft,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        FreezmeLogo(size: LogoSize.sm, showText: true),
                        Spacer(),
                        Text('Chats', style: FreezmeTypography.title),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Search chats or messages',
                        prefixIcon: const Icon(Icons.search,
                            color: FreezmeColors.muted),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide:
                              const BorderSide(color: FreezmeColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide:
                              const BorderSide(color: FreezmeColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide:
                              const BorderSide(color: FreezmeColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilterChip(
                          selected: !_showUnreadOnly,
                          onSelected: (_) =>
                              setState(() => _showUnreadOnly = false),
                          label: const Text('All'),
                          selectedColor:
                              FreezmeColors.primary.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: !_showUnreadOnly
                                ? FreezmeColors.primary
                                : FreezmeColors.neutral,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _showUnreadOnly,
                          onSelected: (_) =>
                              setState(() => _showUnreadOnly = true),
                          label: const Text('Unread'),
                          selectedColor:
                              FreezmeColors.primary.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: _showUnreadOnly
                                ? FreezmeColors.primary
                                : FreezmeColors.neutral,
                          ),
                        ),
                        const Spacer(),
                        const Row(
                          children: [
                            Icon(Icons.done_all,
                                size: 16, color: FreezmeColors.muted),
                            SizedBox(width: 4),
                            Text('Read', style: FreezmeTypography.bodyMuted),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RepaintBoundary( // Wrap expensive list in RepaintBoundary
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: flow.repository.watchMatches(),
                    builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // Show skeleton loading for better UX
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: 5,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, __) => const _SkeletonChatItem(),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Could not load chats',
                                style: FreezmeTypography.bodyMuted),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {}); // Trigger rebuild
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final matches = snapshot.data ?? [];
                    final mapped = matches.map((m) {
                      final id = m['id']?.toString() ?? '';
                      final displayName = m['name']?.toString() ??
                          (m['otherUserName']?.toString() ?? 'Freezme Match');
                      final photo = m['photoUrl']?.toString() ?? '';
                      final lastMsg =
                          m['lastMessage']?.toString() ?? 'Tap to open chat';
                      // Use pre-formatted timeLabel from repository
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
                    
                    // Sort: Pinned first, then by date
                    mapped.sort((a, b) {
                      if (a.isPinned != b.isPinned) {
                        return a.isPinned ? -1 : 1;
                      }
                      // Assuming original list is already sorted by date
                      // For now, we assume the stream provides them in a suitable order for non-pinned.
                      // If not, we'd need a timestamp comparison here.
                      return 0;
                    });

                    _conversations = mapped;

                    final visibleConversations =
                        _filterConversations(_conversations);

                    if (visibleConversations.isEmpty) {
                      return const Center(
                        child: Text(
                          'No conversations yet.\nInvite a vibe to start chatting.',
                          textAlign: TextAlign.center,
                          style: FreezmeTypography.bodyMuted,
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        // watchMatches is a stream, so refresh might just be a no-op or re-establishing stream
                        // But for UI feel we can delay a bit
                        await Future.delayed(const Duration(seconds: 1));
                        setState(() {});
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        // Performance optimizations
                        itemExtent: 92, // Approximate height of each chat card
                        addAutomaticKeepAlives: true, // Keep alive for better scroll performance
                        addRepaintBoundaries: true, // Isolate repaints
                        cacheExtent: 500, // Cache more items for smoother scrolling
                        itemCount: visibleConversations.length,
                        itemBuilder: (context, index) {
                          final convo = visibleConversations[index];
                          return Dismissible(
                            key: ValueKey(convo.chatId), // Use ValueKey for better performance
                            background: Container(
                              color: FreezmeColors.primary,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              child: const Icon(Icons.archive, color: Colors.white),
                            ),
                            secondaryBackground: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.endToStart) {
                                // Delete
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Chat?'),
                                    content: const Text(
                                        'This will remove the chat for you. Messages will remain for the other person.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await flow.repository.deleteChat(convo.chatId);
                                  return true;
                                }
                                return false;
                              } else {
                                // Archive
                                await flow.repository.archiveChat(convo.chatId, true);
                                if (!context.mounted) return true;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${convo.displayName} archived'),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () => flow.repository.archiveChat(convo.chatId, false),
                                    ),
                                  ),
                                );
                                return true;
                              }
                            },
                            child: Card(
                              elevation: convo.unread > 0 ? 4 : 2,
                              shadowColor: convo.unread > 0
                                  ? FreezmeColors.primary.withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: convo.isPinned
                                    ? const BorderSide(
                                        color: FreezmeColors.primary,
                                        width: 1.5,
                                      )
                                    : BorderSide.none,
                              ),
                              color: convo.isPinned
                                  ? FreezmeColors.primary.withValues(alpha: 0.05)
                                  : Colors.white,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  setState(() {
                                  convo.unread = 0;
                                  convo.status = _MessageStatus.read;
                                });
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
                                onLongPress: () {
                                  showModalBottomSheet(
                                    context: context,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                    ),
                                    builder: (context) => Container(
                                      padding: const EdgeInsets.symmetric(vertical: 20),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: FreezmeColors.border,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          ListTile(
                                            leading: Icon(
                                              convo.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                                              color: FreezmeColors.primary,
                                            ),
                                            title: Text(convo.isPinned ? 'Unpin Chat' : 'Pin Chat'),
                                            subtitle: Text(
                                              convo.isPinned
                                                  ? 'Remove from top'
                                                  : 'Keep at top of chat list',
                                              style: FreezmeTypography.bodyMuted,
                                            ),
                                            onTap: () {
                                              Navigator.pop(context);
                                              flow.repository.pinChat(convo.chatId, !convo.isPinned);
                                            },
                                          ),
                                          const Divider(),
                                          ListTile(
                                            leading: Icon(
                                              convo.isMuted ? Icons.notifications_active : Icons.notifications_off,
                                              color: FreezmeColors.accent,
                                            ),
                                            title: Text(convo.isMuted ? 'Unmute Chat' : 'Mute Chat'),
                                            subtitle: Text(
                                              convo.isMuted
                                                  ? 'Turn on notifications'
                                                  : 'Stop receiving notifications',
                                              style: FreezmeTypography.bodyMuted,
                                            ),
                                            onTap: () {
                                              Navigator.pop(context);
                                              flow.repository.muteChat(convo.chatId, !convo.isMuted);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: convo.unread > 0
                                                  ? Border.all(
                                                      color: FreezmeColors.primary,
                                                      width: 2.5,
                                                    )
                                                  : null,
                                            ),
                                            child: convo.photoUrl.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: convo.photoUrl,
                                                    imageBuilder: (context, imageProvider) => CircleAvatar(
                                                      backgroundImage: imageProvider,
                                                      radius: 28,
                                                    ),
                                                    placeholder: (context, url) => const CircleAvatar(
                                                      radius: 28,
                                                      child: Icon(Icons.person, size: 28),
                                                    ),
                                                    errorWidget: (context, url, error) => const CircleAvatar(
                                                      radius: 28,
                                                      child: Icon(Icons.person, size: 28),
                                                    ),
                                                    memCacheWidth: 150,
                                                    memCacheHeight: 150,
                                                    maxWidthDiskCache: 150,
                                                    maxHeightDiskCache: 150,
                                                  )
                                                : const CircleAvatar(
                                                    radius: 28,
                                                    child: Icon(Icons.person, size: 28),
                                                  ),
                                          ),
                                          if (convo.unread > 0)
                                            Positioned(
                                              right: -4,
                                              top: -4,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: FreezmeColors.error,
                                                  borderRadius: BorderRadius.circular(10),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: FreezmeColors.error.withValues(alpha: 0.4),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  convo.unread > 9 ? '9+' : '${convo.unread}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          if (convo.isOnline)
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 14,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: FreezmeColors.success,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    convo.displayName,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 16,
                                                      color: FreezmeColors.neutral,
                                                      letterSpacing: -0.3,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                if (convo.isPinned)
                                                  Icon(
                                                    Icons.push_pin,
                                                    size: 16,
                                                    color: FreezmeColors.primary,
                                                  ),
                                                if (convo.isMuted)
                                                  Icon(
                                                    Icons.notifications_off,
                                                    size: 16,
                                                    color: FreezmeColors.muted,
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    convo.isTyping ? 'Typing...' : convo.lastMessage,
                                                    style: TextStyle(
                                                      color: convo.isTyping
                                                          ? FreezmeColors.primary
                                                          : (convo.unread > 0
                                                              ? FreezmeColors.neutral
                                                              : FreezmeColors.muted),
                                                      fontWeight: convo.unread > 0 || convo.isTyping
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                      fontStyle: convo.isTyping
                                                          ? FontStyle.italic
                                                          : FontStyle.normal,
                                                      fontSize: 14,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            convo.timeLabel,
                                            style: TextStyle(
                                              color: convo.unread > 0
                                                  ? FreezmeColors.primary
                                                  : FreezmeColors.muted,
                                              fontSize: 12,
                                              fontWeight: convo.unread > 0
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Icon(
                                            _statusIcon(convo.status),
                                            size: 16,
                                            color: convo.status == _MessageStatus.read
                                                ? FreezmeColors.primary
                                                : FreezmeColors.muted,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                      ),
                    );
                  },
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
