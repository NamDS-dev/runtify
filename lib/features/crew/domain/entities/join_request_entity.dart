// 크루 가입 신청 엔티티
// Firestore: crews/{crewId}/joinRequests/{userId}

class JoinRequestEntity {
  final String userId;
  final String userName;
  final DateTime requestedAt;
  final String status; // "pending" | "approved" | "rejected"

  const JoinRequestEntity({
    required this.userId,
    required this.userName,
    required this.requestedAt,
    this.status = 'pending',
  });

  bool get isPending => status == 'pending';

  factory JoinRequestEntity.fromFirestore(Map<String, dynamic> data) {
    return JoinRequestEntity(
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      requestedAt: data['requestedAt'] != null
          ? (data['requestedAt'] as dynamic).toDate()
          : DateTime.now(),
      status: data['status'] as String? ?? 'pending',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'requestedAt': requestedAt,
      'status': status,
    };
  }
}
