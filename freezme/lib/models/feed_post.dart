/// Represents a social feed post
class FeedPost {
  const FeedPost({
    required this.id,
    required this.authorUid,
    required this.authorName,
    this.authorPhotoUrl,
    this.caption,
    required this.photoUrls,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    this.isLikedByMe = false,
    this.visibility = 'public',
  });

  final String id;
  final String authorUid;
  final String authorName;
  final String? authorPhotoUrl;
  final String? caption;
  final List<String> photoUrls;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe;
  final String visibility; // 'public' | 'connections'

  /// Create from JSON
  factory FeedPost.fromJson(
    Map<String, dynamic> json, {
    required String documentId,
    bool isLikedByMe = false,
  }) {
    return FeedPost(
      id: documentId,
      authorUid: json['authorUid'] as String? ?? '',
      authorName: json['authorName'] as String? ?? 'Unknown',
      authorPhotoUrl: json['authorPhotoUrl'] as String?,
      caption: json['caption'] as String?,
      photoUrls: (json['photoUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: _parseDateTime(json['createdAt']),
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      isLikedByMe: isLikedByMe,
      visibility: json['visibility'] as String? ?? 'public',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'authorUid': authorUid,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'caption': caption,
      'photoUrls': photoUrls,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'visibility': visibility,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  FeedPost copyWith({
    String? id,
    String? authorUid,
    String? authorName,
    String? authorPhotoUrl,
    String? caption,
    List<String>? photoUrls,
    DateTime? createdAt,
    int? likeCount,
    int? commentCount,
    bool? isLikedByMe,
    String? visibility,
  }) {
    return FeedPost(
      id: id ?? this.id,
      authorUid: authorUid ?? this.authorUid,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      caption: caption ?? this.caption,
      photoUrls: photoUrls ?? this.photoUrls,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      visibility: visibility ?? this.visibility,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}
