import 'package:equatable/equatable.dart';

// 앱 내에서 사용하는 순수 유저 데이터 객체
class UserEntity extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? profileImageUrl;
  final int experience;       // 경험치 - 레벨업 기준, 소비 불가
  final int points;           // 포인트 - 리워드 스토어에서 사용하는 재화
  final int level;            // 현재 레벨 (experience 기반 자동 계산)
  final double totalDistance; // 총 러닝 거리 (km)
  final String? crewId;       // 소속 크루 ID (없으면 null)
  final int streak;           // 연속 러닝 일수 (스트릭 보너스 계산용)
  final DateTime? lastRunDate; // 마지막 러닝 날짜 (스트릭 갱신 기준)

  // ── 홈 지역 (Phase 4: GPS 기반 지역 설정) ──────────────────────
  final String? homeRegionSi;   // 시·도 (예: "서울특별시")
  final String? homeRegionGu;   // 구·군 (예: "강남구")
  final String? homeRegionDong; // 동 (예: "역삼동")

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl,
    this.experience = 0,
    this.points = 0,
    this.level = 1,
    this.totalDistance = 0.0,
    this.crewId,
    this.streak = 0,
    this.lastRunDate,
    this.homeRegionSi,
    this.homeRegionGu,
    this.homeRegionDong,
  });

  // 다음 레벨까지 필요한 경험치 (레벨 * 100)
  int get expForNextLevel => level * 100;

  // 현재 레벨 내 진행도 (0.0 ~ 1.0)
  double get levelProgress {
    final currentLevelExp = (level - 1) * 100;
    final progress = (experience - currentLevelExp) / expForNextLevel;
    return progress.clamp(0.0, 1.0);
  }

  // 다음 레벨까지 남은 경험치
  int get expToNextLevel {
    final currentLevelExp = (level - 1) * 100;
    return expForNextLevel - (experience - currentLevelExp);
  }

  // 스트릭 보너스 배율 (3일 연속 ×1.2, 7일 연속 ×1.5)
  double get streakMultiplier {
    if (streak >= 7) return 1.5;
    if (streak >= 3) return 1.2;
    return 1.0;
  }

  // 홈 지역 표시용 문자열 (예: "강남구 역삼동" / 미설정 시 null)
  String? get homeRegionLabel {
    if (homeRegionGu == null && homeRegionDong == null) return null;
    final parts = [homeRegionGu, homeRegionDong].where((s) => s != null && s.isNotEmpty).toList();
    return parts.join(' ');
  }

  @override
  List<Object?> get props => [id, name, email, experience, points, level, streak, homeRegionSi, homeRegionGu, homeRegionDong];
}
