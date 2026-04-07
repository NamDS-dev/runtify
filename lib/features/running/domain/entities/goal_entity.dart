// 목표 유형 열거형
enum GoalType { weeklyDistance, monthlyDistance, weeklyCount, streak }

// GoalType 확장 메서드 — 라벨, 아이콘, 단위 제공
extension GoalTypeExtension on GoalType {
  // 화면에 표시할 목표 이름
  String get label {
    switch (this) {
      case GoalType.weeklyDistance:
        return '주간 거리 목표';
      case GoalType.monthlyDistance:
        return '월간 거리 목표';
      case GoalType.weeklyCount:
        return '주간 횟수 목표';
      case GoalType.streak:
        return '연속 달리기';
    }
  }

  // 목표 유형 아이콘 이모지
  String get icon {
    switch (this) {
      case GoalType.weeklyDistance:
        return '🏃';
      case GoalType.monthlyDistance:
        return '📅';
      case GoalType.weeklyCount:
        return '🔢';
      case GoalType.streak:
        return '🔥';
    }
  }

  // 목표 수치 단위
  String get unit {
    switch (this) {
      case GoalType.weeklyDistance:
        return 'km';
      case GoalType.monthlyDistance:
        return 'km';
      case GoalType.weeklyCount:
        return '회';
      case GoalType.streak:
        return '일';
    }
  }
}

// 개인 러닝 목표 엔티티 (순수 Dart — Equatable 미사용)
class GoalEntity {
  final String id;
  final GoalType type;        // 목표 유형
  final double targetValue;  // 목표 수치
  final double currentValue; // 현재 달성 수치
  final String period;       // 기간 ("2026-W12" 또는 "2026-03")
  final bool isCompleted;    // 목표 달성 여부
  final DateTime createdAt;  // 생성 시각

  const GoalEntity({
    required this.id,
    required this.type,
    required this.targetValue,
    required this.currentValue,
    required this.period,
    required this.isCompleted,
    required this.createdAt,
  });

  // 달성률 (0.0 ~ 1.0, 최대 1.0 클램프)
  double get progress => targetValue > 0
      ? (currentValue / targetValue).clamp(0.0, 1.0)
      : 0.0;
}
