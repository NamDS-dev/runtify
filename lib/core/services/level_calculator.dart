import 'dart:math' as math;

/// 레벨 시스템 — 지수 공식 기반 (가설 2 검증, 2026-05-06).
///
/// 공식: `expRequired(N) = (100 * 1.5^(N-1)).round()`
/// - Lv.1 → Lv.2: 100 EXP
/// - Lv.2 → Lv.3: 150
/// - Lv.5 → Lv.6: 506
/// - Lv.10 → Lv.11: 3,844
/// - Lv.20 → Lv.21: 221,683
///
/// 초반 빠르게 → 후반 느리게 (게임 표준). 운영 시 곡선이 부담되면 base/factor 튜닝.
class LevelCalculator {
  static const int _baseExp = 100;
  static const double _factor = 1.5;
  // 레벨 cap — 무한 루프 방지 + Lv.50 = 전설의 러너에 맞춤
  static const int maxLevel = 99;

  /// 현재 레벨에서 다음 레벨로 가는 데 필요한 EXP.
  static int expRequiredForLevelUp(int currentLevel) {
    if (currentLevel < 1) return _baseExp;
    return (_baseExp * math.pow(_factor, currentLevel - 1)).round();
  }

  /// Lv.1 ~ Lv.[targetLevel] 까지 도달에 필요한 누적 EXP 합.
  ///
  /// Lv.1 도달 = 0 EXP, Lv.2 도달 = 100, Lv.3 도달 = 250, ...
  static int totalExpToReachLevel(int targetLevel) {
    if (targetLevel <= 1) return 0;
    int sum = 0;
    for (int i = 1; i < targetLevel; i++) {
      sum += expRequiredForLevelUp(i);
    }
    return sum;
  }

  /// 누적 EXP 로부터 레벨 계산.
  static int levelFromTotalExp(int totalExp) {
    if (totalExp < 0) return 1;
    int level = 1;
    while (level < maxLevel) {
      final next = totalExpToReachLevel(level + 1);
      if (totalExp < next) break;
      level++;
    }
    return level;
  }

  /// 현재 레벨 진입 후 누적된 EXP — 진행바용.
  static int expIntoCurrentLevel(int totalExp, int currentLevel) {
    final base = totalExpToReachLevel(currentLevel);
    final into = totalExp - base;
    return into < 0 ? 0 : into;
  }

  /// 현재 레벨 → 다음 레벨까지의 진행률 (0.0 ~ 1.0). 최고 레벨이면 1.0.
  static double progressToNextLevel(int totalExp, int currentLevel) {
    if (currentLevel >= maxLevel) return 1.0;
    final into = expIntoCurrentLevel(totalExp, currentLevel);
    final required = expRequiredForLevelUp(currentLevel);
    if (required <= 0) return 1.0;
    return (into / required).clamp(0.0, 1.0);
  }
}
