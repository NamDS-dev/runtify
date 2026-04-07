// 코스 엔티티 — 유저가 저장한 러닝 코스 정보
// Phase 8: 런닝 코스 저장 & 공유

import '../../../running/domain/entities/running_session_entity.dart';

class CourseEntity {
  final String id;
  final String creatorId; // 코스 생성자 userId
  final String creatorName; // 생성자 닉네임
  final String name; // 코스 이름
  final String regionGu; // 지역 (구/군)
  final String regionSi; // 지역 (시/도)
  final double distanceKm; // 코스 거리 (km)
  final int difficulty; // 난이도 (1~5)
  final List<LatLngPoint> routePoints; // GPS 경로 포인트
  final int runCount; // 이 코스를 달린 횟수
  final DateTime createdAt;

  const CourseEntity({
    required this.id,
    required this.creatorId,
    this.creatorName = '',
    required this.name,
    this.regionGu = '',
    this.regionSi = '',
    this.distanceKm = 0.0,
    this.difficulty = 1,
    this.routePoints = const [],
    this.runCount = 0,
    required this.createdAt,
  });

  // 난이도 별점 문자열 (⭐ × difficulty)
  String get difficultyStars => '⭐' * difficulty;

  // Firestore → CourseEntity
  factory CourseEntity.fromFirestore(Map<String, dynamic> data, String id) {
    final rawRoute = data['routePoints'] as List<dynamic>? ?? [];
    final routePoints = rawRoute
        .map((p) => LatLngPoint(
              lat: (p['lat'] as num?)?.toDouble() ?? 0.0,
              lng: (p['lng'] as num?)?.toDouble() ?? 0.0,
            ))
        .toList();

    return CourseEntity(
      id: id,
      creatorId: data['creatorId'] as String? ?? '',
      creatorName: data['creatorName'] as String? ?? '',
      name: data['name'] as String? ?? '',
      regionGu: data['regionGu'] as String? ?? '',
      regionSi: data['regionSi'] as String? ?? '',
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0.0,
      difficulty: (data['difficulty'] as num?)?.toInt() ?? 1,
      routePoints: routePoints,
      runCount: (data['runCount'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  // CourseEntity → Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'creatorId': creatorId,
      'creatorName': creatorName,
      'name': name,
      'regionGu': regionGu,
      'regionSi': regionSi,
      'distanceKm': distanceKm,
      'difficulty': difficulty,
      'routePoints':
          routePoints.map((p) => {'lat': p.lat, 'lng': p.lng}).toList(),
      'runCount': runCount,
      'createdAt': createdAt,
    };
  }
}
