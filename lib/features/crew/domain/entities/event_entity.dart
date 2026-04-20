// 크루 이벤트 엔티티 — 그룹 러닝 모집
// Firestore: crews/{crewId}/events/{eventId}

class CrewEventEntity {
  final String id;
  final String crewId;
  final String title;
  final DateTime date; // 이벤트 날짜+시간
  final String locationName; // 장소명
  final List<String> participantIds; // 참가자 userId 목록
  final String createdBy; // 생성자 userId
  final DateTime createdAt;

  const CrewEventEntity({
    required this.id,
    required this.crewId,
    required this.title,
    required this.date,
    this.locationName = '',
    this.participantIds = const [],
    required this.createdBy,
    required this.createdAt,
  });

  int get participantCount => participantIds.length;
  bool get isUpcoming => date.isAfter(DateTime.now());
  bool isJoinedBy(String userId) => participantIds.contains(userId);

  factory CrewEventEntity.fromFirestore(Map<String, dynamic> data, String id) {
    return CrewEventEntity(
      id: id,
      crewId: data['crewId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      date: data['date'] != null
          ? (data['date'] as dynamic).toDate()
          : DateTime.now(),
      locationName: data['locationName'] as String? ?? '',
      participantIds: List<String>.from(data['participantIds'] ?? []),
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'crewId': crewId,
      'title': title,
      'date': date,
      'locationName': locationName,
      'participantIds': participantIds,
      'createdBy': createdBy,
      'createdAt': createdAt,
    };
  }
}
