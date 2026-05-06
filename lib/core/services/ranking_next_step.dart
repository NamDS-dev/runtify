/// "X km 더 뛰면 N위" 계산 결과.
typedef RankingNextStepResult = ({double gapKm, int targetRank});

/// 랭킹 next-step 계산기 (가설 1 — 2026-05-06).
///
/// 사용자 호기심 자극을 위한 동기 부여 표시. 랭킹 페이지 "내 지역" 배너에 표시.
/// 포인트 1점 = 0.1km (= 10P/km 공식 역산).
class RankingNextStep {
  /// 다음 순위로 도달하기 위해 더 달려야 하는 km 계산.
  ///
  /// [myRank] 가 1(=1위)이면 null — 더 위 없음.
  /// [myRank] 가 0 이하 / 순위권 밖이면 null.
  /// 동점인 경우 (gap ≤ 0) null — "이미 도달" 처리.
  static RankingNextStepResult? calc({
    required int myRank,
    required int myPoints,
    required List<int> sortedTotalPoints,
  }) {
    if (myRank <= 1) return null;
    if (sortedTotalPoints.isEmpty) return null;
    final aboveIdx = myRank - 2; // 1-indexed 랭킹 → 0-indexed
    if (aboveIdx < 0 || aboveIdx >= sortedTotalPoints.length) return null;
    final aboveTotal = sortedTotalPoints[aboveIdx];
    final gapPoints = aboveTotal - myPoints;
    if (gapPoints <= 0) return null; // 동점 또는 이미 더 높은 점수
    final gapKm = gapPoints / 10.0; // 10P = 1km
    return (gapKm: gapKm, targetRank: myRank - 1);
  }
}
