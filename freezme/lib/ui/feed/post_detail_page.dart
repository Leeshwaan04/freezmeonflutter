import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../main.dart';
import '../../models/feed_post.dart';
import '../../models/post_comment.dart';
import '../theme.dart';
import 'feed_page.dart';

/// Page for viewing post details and comments
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.post,
  });

  final FeedPost post;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _commentController = TextEditingController();
  bool _isSending = false;
  late FeedPost _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final flow = AppFlowScope.of(context, listen: false);
      await flow.repository.addComment(
        postId: _post.id,
        text: text,
      );
      _commentController.clear();
      
      // Optimistically update comment count
      setState(() {
        _post = _post.copyWith(commentCount: _post.commentCount + 1);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _deleteComment(PostComment comment) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || comment.authorUid != currentUser.uid) return;

    try {
      final flow = AppFlowScope.of(context, listen: false);
      await flow.repository.deleteComment(
        postId: _post.id,
        commentId: comment.id,
      );
      
      // Optimistically update comment count
      setState(() {
        _post = _post.copyWith(commentCount: _post.commentCount - 1);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting comment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = AppFlowScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: FreezmeColors.background,
        foregroundColor: FreezmeColors.text,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post content
                  PostCard(
                    post: _post,
                    onLike: () async {
                      // Toggle like logic similar to FeedPage
                      // For simplicity, we'll just call the repo
                      try {
                        if (_post.isLikedByMe) {
                          await flow.repository.unlikePost(_post.id);
                          setState(() {
                            _post = _post.copyWith(
                              likeCount: _post.likeCount - 1,
                              isLikedByMe: false,
                            );
                          });
                        } else {
                          await flow.repository.likePost(_post.id);
                          setState(() {
                            _post = _post.copyWith(
                              likeCount: _post.likeCount + 1,
                              isLikedByMe: true,
                            );
                          });
                        }
                      } catch (e) {
                        // Handle error
                      }
                    },
                    onComment: () {}, // Already here
                    onDelete: () {
                      // Handle delete
                      Navigator.pop(context);
                    },
                  ),

                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Comments list
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: flow.repository.watchComments(_post.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ));
                      }

                      final commentsData = snapshot.data ?? [];
                      if (commentsData.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No comments yet. Be the first!',
                              style: TextStyle(color: FreezmeColors.textMuted),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: commentsData.length,
                        itemBuilder: (context, index) {
                          final data = commentsData[index];
                          final comment = PostComment.fromJson(
                            data,
                            documentId: data['id'],
                            postId: _post.id,
                          );

                          return _CommentItem(
                            comment: comment,
                            onDelete: () => _deleteComment(comment),
                          );
                        },
                      );
                    },
                  ),
                  
                  // Bottom padding for input
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Comment input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: FreezmeColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: FreezmeColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _sendComment,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: FreezmeColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({
    required this.comment,
    required this.onDelete,
  });

  final PostComment comment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnComment = currentUser != null && comment.authorUid == currentUser.uid;

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundImage: comment.authorPhotoUrl != null
            ? CachedNetworkImageProvider(comment.authorPhotoUrl!)
            : null,
        child: comment.authorPhotoUrl == null
            ? Text(comment.authorName[0].toUpperCase())
            : null,
      ),
      title: Row(
        children: [
          Text(
            comment.authorName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Text(
            timeago.format(comment.createdAt, locale: 'en_short'),
            style: TextStyle(color: FreezmeColors.textMuted, fontSize: 12),
          ),
        ],
      ),
      subtitle: Text(comment.text),
      trailing: isOwnComment
          ? IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: onDelete,
            )
          : null,
    );
  }
}
