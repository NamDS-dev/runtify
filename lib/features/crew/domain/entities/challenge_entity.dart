// 챌린지 타입: 합산거리 / 참여율 / 연속달리기
enum ChallengeType { distance, participation, streak }

// 챌린지 상태: 진행 중 / 완료 / 실패
enum ChallengeStatus { active, completed, failed }

// 위클리 챌린지 도메인 엔티티 (순수 Dart, 외부 의존성 없음)
class ChallengeEntity {
  final String id;
  final ChallengeType type;
  final double targetValue;   // 목표값 (km 또는 참여 인원 수 또는 연속 일수)
  final double currentValue;  // 현재 달성값
  final DateTime startDate;   // 챌린지 시작일
  final DateTime endDate;     // 챌린지 종료일 (보통 7일 후)
  final int bonusPoints;      // 달성 시 크루원 전원 지급 보너스 포인트
  final ChallengeStatus status;
  final int participantCount; // 이번 주 최소 1회 달린 인원 수

  const ChallengeEntity({
    required this.id,
    required this.type,
    required this.targetValue,
    required this.currentValue,
    required this.startDate,
    required this.endDate,
    required this.bonusPoints,
    required this.status,
    required this.participantCount,
  });

  // 진행률 (0.0 ~ 1.0)
  double get progress => targetValue > 0
      ? (currentValue / targetValue).clamp(0.0, 1.0)
      : 0.0;

  // 남은 일수 (D-day 계산)
  int get daysLeft {
    final now = DateTime.now();
    final diff = endDate.difference(now).inDays;
    return diff < 0 ? 0 : diff;
  }

  // 챌린지 종료 여부
  bool get isExpired => DateTime.now().isAfter(endDate);

  // 타입별 표시 이름
  String get typeLabel {
    switch (type) {
      case ChallengeType.distance:
        return '합산거리';
      case ChallengeType.participation:
        return '참여율';
      case ChallengeType.streak:
        return '연속달리기';
    }
  }

  // 단위 표시
  String get unit {
    switch (type) {
      case ChallengeType.distance:
        return 'km';
      case ChallengeType.participation:
        return '명';
      case ChallengeType.streak:
        return '일';
    }
  }
}
