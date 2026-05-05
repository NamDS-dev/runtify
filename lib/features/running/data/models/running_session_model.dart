import '../../domain/entities/lap_data.dart';
import '../../domain/entities/running_session_entity.dart';

class RunningSessionModel extends RunningSessionEntity {
  const RunningSessionModel({
    required super.id,
    required super.userId,
    required super.startTime,
    super.endTime,
    super.distanceKm,
    super.durationSeconds,
    super.avgPaceMinPerKm,
    super.avgHeartRate,
    super.calories,
    super.expEarned,
    super.pointsEarned,
    super.region,
    super.routePoints,
    super.splitPaces,
    // 하위 호환 지역 필드 (레거시)
    super.regionDong,
    super.regionGu,
    super.regionSi,
    // 실제 뛴 위치
    super.geoRegionSi,
    super.geoRegionGu,
    super.geoRegionDong,
    // 랭킹 기여 지역
    super.rankingRegionSi,
    super.rankingRegionGu,
    super.rankingRegionDong,
    // 신규 획득 배지 (Firestore 미저장, 메모리 전달용)
    super.newBadgeIds,
    // 신규 갱신 PB (Firestore 미저장, 결과 화면 🏆 배너용)
    super.newPersonalRecords,
    // 사용자 부여 제목/메모
    super.title,
    super.memo,
    super.laps,
  });

  factory RunningSessionModel.fromFirestore(
    Map<String, dynamic> data,
    String id,
  ) {
    // routePoints: [{lat, lng}] 목록 역직렬화
    final rawRoute = data['routePoints'] as List<dynamic>? ?? [];
    final routePoints = rawRoute
        .map((p) => LatLngPoint(
              lat: (p['lat'] ?? 0.0).toDouble(),
              lng: (p['lng'] ?? 0.0).toDouble(),
            ))
        .toList();

    // splitPaces: [{km, pace}] 목록 역직렬화
    final rawSplits = data['splitPaces'] as List<dynamic>? ?? [];
    final splitPaces = rawSplits
        .map((s) => SplitPace(
              km: (s['km'] ?? 0) as int,
              pace: (s['pace'] ?? 0.0).toDouble(),
            ))
        .toList();

    // laps: [{km, splitSeconds, pace, avgHeartRate}] 역직렬화 (없으면 빈 리스트)
    final rawLaps = data['laps'] as List<dynamic>? ?? [];
    final laps = rawLaps
        .map((l) => LapData.fromJson((l as Map).cast<String, dynamic>()))
        .toList();

    return RunningSessionModel(
      id: id,
      userId: data['userId'] ?? '',
      startTime: DateTime.parse(data['startTime']),
      endTime: data['endTime'] != null ? DateTime.parse(data['endTime']) : null,
      distanceKm: (data['distanceKm'] ?? 0.0).toDouble(),
      durationSeconds: data['durationSeconds'] ?? 0,
      avgPaceMinPerKm: (data['avgPaceMinPerKm'] ?? 0.0).toDouble(),
      avgHeartRate: (data['avgHeartRate'] ?? 0.0).toDouble(),
      calories: (data['calories'] ?? 0.0).toDouble(),
      expEarned: data['expEarned'] ?? 0,
      pointsEarned: data['pointsEarned'] ?? 0,
      region: data['region'] ?? '',
      routePoints: routePoints,
      splitPaces: splitPaces,
      laps: laps,
      // 하위 호환 지역 필드 역직렬화 (null 가능)
      regionDong: data['regionDong'] as String?,
      regionGu: data['regionGu'] as String?,
      regionSi: data['regionSi'] as String?,
      // 실제 뛴 위치 역직렬화
      geoRegionSi: data['geoRegionSi'] as String?,
      geoRegionGu: data['geoRegionGu'] as String?,
      geoRegionDong: data['geoRegionDong'] as String?,
      // 랭킹 기여 지역 역직렬화
      rankingRegionSi: data['rankingRegionSi'] as String?,
      rankingRegionGu: data['rankingRegionGu'] as String?,
      rankingRegionDong: data['rankingRegionDong'] as String?,
      // 사용자 제목/메모 역직렬화
      title: data['title'] as String?,
      memo: data['memo'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'distanceKm': distanceKm,
      'durationSeconds': durationSeconds,
      'avgPaceMinPerKm': avgPaceMinPerKm,
      'avgHeartRate': avgHeartRate,
      'calories': calories,
      'expEarned': expEarned,
      'pointsEarned': pointsEarned,
      'region': region,
      // GPS 경로 포인트 직렬화
      'routePoints': routePoints.map((p) => {'lat': p.lat, 'lng': p.lng}).toList(),
      // 구간 페이스 직렬화
      'splitPaces': splitPaces.map((s) => {'km': s.km, 'pace': s.pace}).toList(),
      // 랩 데이터 직렬화 (비어 있으면 저장 안 함 — 레거시 문서 깔끔하게 유지)
      if (laps.isNotEmpty) 'laps': laps.map((l) => l.toJson()).toList(),
      // 하위 호환 지역 계층 필드 (null이면 저장 안 함)
      if (regionDong != null) 'regionDong': regionDong,
      if (regionGu != null) 'regionGu': regionGu,
      if (regionSi != null) 'regionSi': regionSi,
      // 실제 뛴 위치 (null이면 저장 안 함)
      if (geoRegionSi != null) 'geoRegionSi': geoRegionSi,
      if (geoRegionGu != null) 'geoRegionGu': geoRegionGu,
      if (geoRegionDong != null) 'geoRegionDong': geoRegionDong,
      // 랭킹 기여 지역 (null이면 저장 안 함)
      if (rankingRegionSi != null) 'rankingRegionSi': rankingRegionSi,
      if (rankingRegionGu != null) 'rankingRegionGu': rankingRegionGu,
      if (rankingRegionDong != null) 'rankingRegionDong': rankingRegionDong,
      // 사용자 제목/메모 (null이면 저장 안 함)
      if (title != null && title!.isNotEmpty) 'title': title,
      if (memo != null && memo!.isNotEmpty) 'memo': memo,
      // newBadgeIds/newPersonalRecords 는 Firestore 미저장 (메모리 전달용)
    };
  }

  // 배지 ID 목록을 추가한 새 인스턴스 반환
  RunningSessionModel copyWithNewBadges(List<String> badgeIds) {
    return _copy(newBadgeIds: badgeIds);
  }

  // PB 갱신 거리 키 목록을 추가한 새 인스턴스 반환
  RunningSessionModel copyWithNewPersonalRecords(List<String> prKeys) {
    return _copy(newPersonalRecords: prKeys);
  }

  // 내부 복제 헬퍼 — 모든 필드 보존, 변경할 부분만 override
  RunningSessionModel _copy({
    List<String>? newBadgeIds,
    List<String>? newPersonalRecords,
  }) {
    return RunningSessionModel(
      id: id,
      userId: userId,
      startTime: startTime,
      endTime: endTime,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      avgPaceMinPerKm: avgPaceMinPerKm,
      avgHeartRate: avgHeartRate,
      calories: calories,
      expEarned: expEarned,
      pointsEarned: pointsEarned,
      region: region,
      routePoints: routePoints,
      splitPaces: splitPaces,
      regionDong: regionDong,
      regionGu: regionGu,
      regionSi: regionSi,
      geoRegionSi: geoRegionSi,
      geoRegionGu: geoRegionGu,
      geoRegionDong: geoRegionDong,
      rankingRegionSi: rankingRegionSi,
      rankingRegionGu: rankingRegionGu,
      rankingRegionDong: rankingRegionDong,
      newBadgeIds: newBadgeIds ?? this.newBadgeIds,
      newPersonalRecords: newPersonalRecords ?? this.newPersonalRecords,
      title: title,
      memo: memo,
      laps: laps,
    );
  }
}
