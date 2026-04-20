// 크루 게시글 엔티티
// Firestore: crews/{crewId}/posts/{postId}

class PostEntity {
  final String id;
  final String crewId;
  final String authorId;
  final String authorName;
  final String content; // 게시글 본문
  final String? imageUrl; // 사진 URL (선택)
  final List<String> likes; // 좋아요한 유저 ID 목록
  final int commentCount; // 댓글 수
  final DateTime createdAt;

  const PostEntity({
    required this.id,
    required this.crewId,
    required this.authorId,
    this.authorName = '',
    required this.content,
    this.imageUrl,
    this.likes = const [],
    this.commentCount = 0,
    required this.createdAt,
  });

  // 좋아요 수
  int get likeCount => likes.length;

  // 특정 유저가 좋아요했는지
  bool isLikedBy(String userId) => likes.contains(userId);

  // Firestore → PostEntity
  factory PostEntity.fromFirestore(Map<String, dynamic> data, String id) {
    return PostEntity(
      id: id,
      crewId: data['crewId'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      content: data['content'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      likes: List<String>.from(data['likes'] ?? []),
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  // PostEntity → Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'crewId': crewId,
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'likes': likes,
      'commentCount': commentCount,
      'createdAt': createdAt,
    };
  }
}
