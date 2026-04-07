import '../../domain/entities/user_entity.dart';

// Firebase Firestore와 주고받는 데이터 모델
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    super.profileImageUrl,
    super.experience,
    super.points,
    super.level,
    super.totalDistance,
    super.crewId,
    super.streak,
    super.lastRunDate,
    super.homeRegionSi,
    super.homeRegionGu,
    super.homeRegionDong,
  });

  // Firestore 문서에서 UserModel 생성
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    // lastRunDate: Firestore Timestamp 또는 ISO 문자열 모두 처리
    DateTime? lastRunDate;
    final rawDate = data['lastRunDate'];
    if (rawDate != null) {
      if (rawDate is String) {
        lastRunDate = DateTime.tryParse(rawDate);
      } else {
        // Firestore Timestamp → DateTime
        lastRunDate = (rawDate as dynamic).toDate() as DateTime?;
      }
    }

    return UserModel(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      experience: data['experience'] ?? 0,
      points: data['points'] ?? 0,
      level: data['level'] ?? 1,
      totalDistance: (data['totalDistance'] ?? 0.0).toDouble(),
      crewId: data['crewId'],
      streak: data['streak'] ?? 0,
      lastRunDate: lastRunDate,
      // 홈 지역 (Phase 4)
      homeRegionSi: data['homeRegionSi'] as String?,
      homeRegionGu: data['homeRegionGu'] as String?,
      homeRegionDong: data['homeRegionDong'] as String?,
    );
  }

  // UserModel을 Firestore에 저장할 Map으로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'profileImageUrl': profileImageUrl,
      'experience': experience,
      'points': points,
      'level': level,
      'totalDistance': totalDistance,
      'crewId': crewId,
      'streak': streak,
      'lastRunDate': lastRunDate?.toIso8601String(),
      // 홈 지역 (Phase 4)
      'homeRegionSi': homeRegionSi,
      'homeRegionGu': homeRegionGu,
      'homeRegionDong': homeRegionDong,
    };
  }
}
