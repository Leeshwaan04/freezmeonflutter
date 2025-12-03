import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Create from Firestore document
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
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      isLikedByMe: isLikedByMe,
      visibility: json['visibility'] as String? ?? 'public',
    );
  }

  /// Convert to Firestore document
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
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
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
}
