import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Create from Firestore document
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
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'authorUid': authorUid,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
