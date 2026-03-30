/// Represents a comment on a feed post
class PostComment {
  const PostComment({
    required this.id,
    required this.postId,
    required this.authorUid,
    required this.authorName,
    this.authorPhotoUrl,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorUid;
  final String authorName;
  final String? authorPhotoUrl;
  final String text;
  final DateTime createdAt;

  /// Create from JSON
  factory PostComment.fromJson(
    Map<String, dynamic> json, {
    required String documentId,
    required String postId,
  }) {
    return PostComment(
      id: documentId,
      postId: postId,
      authorUid: json['authorUid'] as String? ?? '',
      authorName: json['authorName'] as String? ?? 'Unknown',
      authorPhotoUrl: json['authorPhotoUrl'] as String?,
      text: json['text'] as String? ?? '',
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'authorUid': authorUid,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}
