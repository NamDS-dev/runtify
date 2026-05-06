/// 레벨별 칭호 6단계 (가설 2 — 게임화된 캐릭터 성장 경험).
///
/// 단계: Lv.1 신입 / Lv.5 동네 / Lv.10 베테랑 / Lv.20 마스터 / Lv.30 챔피언 / Lv.50 전설
class LevelTitle {
  static const _tiers = <(int minLevel, String title)>[
    (50, '전설의 러너'),
    (30, '챔피언 러너'),
    (20, '마스터 러너'),
    (10, '베테랑 러너'),
    (5, '동네 러너'),
    (1, '신입 러너'),
  ];

  /// 주어진 레벨에 해당하는 칭호 반환.
  /// 레벨이 1 미만이면 신입 러너로 폴백 (음수/0 방어).
  static String forLevel(int level) {
    final clamped = level < 1 ? 1 : level;
    for (final (minLevel, title) in _tiers) {
      if (clamped >= minLevel) return title;
    }
    // 도달 불가 — 폴백
    return '신입 러너';
  }

  /// 다음 칭호까지 남은 레벨 수. 이미 최고 칭호면 null.
  static int? levelsToNextTitle(int level) {
    final clamped = level < 1 ? 1 : level;
    // tiers는 내림차순 — 다음(상위) tier 찾기
    int? next;
    for (final (minLevel, _) in _tiers.reversed) {
      if (minLevel > clamped) {
        next = minLevel;
        break;
      }
    }
    if (next == null) return null;
    return next - clamped;
  }

  /// 다음 칭호 라벨. 이미 최고 칭호면 null.
  static String? nextTitle(int level) {
    final clamped = level < 1 ? 1 : level;
    for (final (minLevel, title) in _tiers.reversed) {
      if (minLevel > clamped) return title;
    }
    return null;
  }
}
