/// 닉네임 사후 변경 정책 (2026-05-06 결정).
///
/// 30일 1회 변경 가능 (Strava 정책 참고). 악용/공격 방지 + UX 균형.
class NicknameChangePolicy {
  static const int cooldownDays = 30;

  /// 현재 닉네임 변경 가능 여부.
  ///
  /// [lastChangedAt] 이 null 이면 한 번도 안 바꾼 상태 → 항상 가능.
  /// 마지막 변경 후 [cooldownDays] 일 경과했으면 가능.
  static bool canChange({
    required DateTime? lastChangedAt,
    DateTime? now,
  }) {
    if (lastChangedAt == null) return true;
    final ref = now ?? DateTime.now();
    final daysSince = ref.difference(lastChangedAt).inDays;
    return daysSince >= cooldownDays;
  }

  /// 다음 변경 가능까지 남은 일수. 이미 변경 가능하면 0.
  static int daysUntilChangeable({
    required DateTime? lastChangedAt,
    DateTime? now,
  }) {
    if (lastChangedAt == null) return 0;
    final ref = now ?? DateTime.now();
    final daysSince = ref.difference(lastChangedAt).inDays;
    final remaining = cooldownDays - daysSince;
    return remaining < 0 ? 0 : remaining;
  }
}
