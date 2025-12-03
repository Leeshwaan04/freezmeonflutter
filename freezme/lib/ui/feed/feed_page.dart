import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../main.dart';
import '../../models/feed_post.dart';
import '../theme.dart';

/// Main feed page displaying social posts
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    // TODO: Implement pagination
  }

  Future<void> _refreshFeed() async {
    // Stream will auto-refresh
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: FreezmeColors.background,
        foregroundColor: FreezmeColors.text,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              // Navigate to create post
              flow.pushIfMissing(AppStage.createPost);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: flow.repository.watchFeed(limit: 20),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: FreezmeColors.error),
                  const SizedBox(height: 16),
                  Text('Error loading feed: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final posts = snapshot.data ?? [];

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_library_outlined, size: 80, color: FreezmeColors.textMuted),
                  const SizedBox(height: 16),
                  const Text(
                    'No posts yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to share something!',
                    style: TextStyle(color: FreezmeColors.textMuted),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => flow.pushIfMissing(AppStage.createPost),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Post'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshFeed,
            child: ListView.builder(
              controller: _scrollController,
              itemCount: posts.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= posts.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final postData = posts[index];
                final post = FeedPost.fromJson(
                  postData,
                  documentId: postData['id'] as String,
                  isLikedByMe: postData['isLikedByMe'] as bool? ?? false,
                );

                return PostCard(
                  post: post,
                  onLike: () => _toggleLike(post),
                  onComment: () => _openComments(post),
                  onDelete: () => _deletePost(post),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleLike(FeedPost post) async {
    try {
      final flow = AppFlowScope.of(context, listen: false);
      
      if (post.isLikedByMe) {
        await flow.repository.unlikePost(post.id);
      } else {
        await flow.repository.likePost(post.id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _openComments(FeedPost post) {
    // TODO: Navigate to post detail/comments page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Comments coming soon!')),
    );
  }

  Future<void> _deletePost(FeedPost post) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || post.authorUid != currentUser.uid) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: FreezmeColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final flow = AppFlowScope.of(context, listen: false);
      await flow.repository.deletePost(post.id);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting post: $e')),
      );
    }
  }
}

/// Widget for displaying a single post
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onDelete,
  });

  final FeedPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnPost = currentUser != null && post.authorUid == currentUser.uid;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundImage: post.authorPhotoUrl != null
                  ? CachedNetworkImageProvider(
                      post.authorPhotoUrl!,
                      maxWidth: 80,
                      maxHeight: 80,
                    )
                  : null,
              child: post.authorPhotoUrl == null
                  ? Text(post.authorName[0].toUpperCase())
                  : null,
            ),
            title: Text(
              post.authorName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              timeago.format(post.createdAt),
              style: TextStyle(color: FreezmeColors.textMuted, fontSize: 12),
            ),
            trailing: isOwnPost
                ? IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showOptionsMenu(context),
                  )
                : null,
          ),

          // Photo carousel
          if (post.photoUrls.isNotEmpty)
            AspectRatio(
              aspectRatio: 1,
              child: PageView.builder(
                itemCount: post.photoUrls.length,
                itemBuilder: (context, index) {
                  return CachedNetworkImage(
                    imageUrl: post.photoUrls[index],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: FreezmeColors.surface,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: FreezmeColors.surface,
                      child: const Icon(Icons.error),
                    ),
                  );
                },
              ),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    post.isLikedByMe ? Icons.favorite : Icons.favorite_border,
                    color: post.isLikedByMe ? FreezmeColors.error : null,
                  ),
                  onPressed: onLike,
                ),
                Text('${post.likeCount}'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: onComment,
                ),
                Text('${post.commentCount}'),
                const Spacer(),
                if (post.visibility == 'connections')
                  Chip(
                    label: const Text('Connections', style: TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: FreezmeColors.surface,
                  ),
              ],
            ),
          ),

          // Caption
          if (post.caption != null && post.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                      text: '${post.authorName} ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: post.caption),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete, color: FreezmeColors.error),
            title: const Text('Delete Post', style: TextStyle(color: FreezmeColors.error)),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
        ],
      ),
    );
  }
}
