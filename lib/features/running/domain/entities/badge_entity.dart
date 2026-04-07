// 배지 엔티티 — MVP 6종 배지 정의 + Firestore 모델
// Phase 6: 배지 & 칭호 시스템

// 배지 ID 상수
class BadgeIds {
  static const streakRunner = 'streak_runner'; // 🔥 불꽃 러너
  static const earlyRunner = 'early_runner'; // 🌙 새벽 러너
  static const speedMaster = 'speed_master'; // ⚡ 스피드 마스터
  static const regionGuard = 'region_guard'; // 🏙️ 지역 지킴이
  static const explorer = 'explorer'; // 🗺️ 원정대
  static const club100km = 'club_100km'; // 💯 100km 클럽
}

// 배지 마스터 정의 (코드 내 상수, Firestore 컬렉션 불필요)
class BadgeDefinition {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String condition; // 달성 조건 설명

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.condition,
  });
}

// MVP 배지 6종 마스터 데이터
const List<BadgeDefinition> allBadges = [
  BadgeDefinition(
    id: BadgeIds.streakRunner,
    name: '불꽃 러너',
    emoji: '🔥',
    description: '7일 연속 런닝 달성!',
    condition: '7일 연속 런닝',
  ),
  BadgeDefinition(
    id: BadgeIds.earlyRunner,
    name: '새벽 러너',
    emoji: '🌙',
    description: '새벽을 깨우는 러너!',
    condition: '6시 이전 10회',
  ),
  BadgeDefinition(
    id: BadgeIds.speedMaster,
    name: '스피드 마스터',
    emoji: '⚡',
    description: '번개같은 속도!',
    condition: "4'30\"/km 이하 5km",
  ),
  BadgeDefinition(
    id: BadgeIds.regionGuard,
    name: '지역 지킴이',
    emoji: '🏙️',
    description: '우리 동네 최강 러너!',
    condition: '구 월간 1위',
  ),
  BadgeDefinition(
    id: BadgeIds.explorer,
    name: '원정대',
    emoji: '🗺️',
    description: '다양한 지역을 누비다!',
    condition: '5개 구 러닝',
  ),
  BadgeDefinition(
    id: BadgeIds.club100km,
    name: '100km 클럽',
    emoji: '💯',
    description: '누적 100km 돌파!',
    condition: '누적 100km 달성',
  ),
];

// 유저가 획득한 배지 데이터 (Firestore: users/{id}/badges/{badgeId})
class EarnedBadge {
  final String badgeId;
  final DateTime earnedAt;

  const EarnedBadge({
    required this.badgeId,
    required this.earnedAt,
  });

  // Firestore → EarnedBadge
  factory EarnedBadge.fromFirestore(Map<String, dynamic> data) {
    return EarnedBadge(
      badgeId: data['badgeId'] as String? ?? '',
      earnedAt: data['earnedAt'] != null
          ? (data['earnedAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  // EarnedBadge → Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'badgeId': badgeId,
      'earnedAt': earnedAt,
    };
  }

  // 배지 정의 찾기
  BadgeDefinition? get definition {
    try {
      return allBadges.firstWhere((b) => b.id == badgeId);
    } catch (_) {
      return null;
    }
  }
}
