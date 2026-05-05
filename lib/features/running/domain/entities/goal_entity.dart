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

  // 합리적 입력 상한 — 비현실적 값(예: 9999km) 차단용
  // 기준: 엘리트 러너 상위치 약간 + 안전 여유
  // - 주간 200km (Strava 상위 1% ≈ 100~150km)
  // - 월간 800km
  // - 주간 횟수 21회 (3회/일 × 7일)
  // - 연속 달리기 365일
  double get maxAllowedValue {
    switch (this) {
      case GoalType.weeklyDistance:
        return 200;
      case GoalType.monthlyDistance:
        return 800;
      case GoalType.weeklyCount:
        return 21;
      case GoalType.streak:
        return 365;
    }
  }

  // 입력 검증 — null 반환 시 통과, 문자열 반환 시 에러 메시지
  // value 가 음수/0 → 에러, 상한 초과 → 에러
  String? validateInputValue(double value) {
    if (value <= 0) return '0보다 큰 값을 입력해주세요';
    if (value > maxAllowedValue) {
      return '$label는 최대 ${maxAllowedValue.toStringAsFixed(0)}$unit까지 설정할 수 있어요';
    }
    return null;
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
