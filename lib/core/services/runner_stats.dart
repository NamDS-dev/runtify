import '../../features/running/domain/entities/running_session_entity.dart';

/// 러너 능력치 3축 — 가설 2 게임화 (2026-05-06).
///
/// 각 축은 0~100 점수로 정규화. fl_chart RadarChart 입력으로 사용.
///
/// 매핑 정책:
/// - **속도**: 최근 5회 평균 페이스 → 5'00"/km = 100점, 7'00"/km = 50점 (선형)
/// - **지구력**: 최근 5회 평균 거리 → 10km = 100점, 3km = 30점 (선형)
/// - **꾸준함**: 최근 30일 러닝 횟수 / 30 × 100 (max 100, 매일 = 100)
class RunnerStats {
  static const int _recentN = 5;
  static const int _consistencyDays = 30;

  /// 최근 [_recentN]회 평균 페이스 → 0~100 점.
  /// 페이스 5.0 → 100, 7.0 → 50, 그 외 선형. 0/음수는 0점.
  static double calcSpeedScore(List<RunningSessionEntity> sessions) {
    final recent = _takeRecent(sessions, _recentN);
    if (recent.isEmpty) return 0;
    final paces = recent
        .where((s) => s.avgPaceMinPerKm > 0)
        .map((s) => s.avgPaceMinPerKm)
        .toList();
    if (paces.isEmpty) return 0;
    final avg = paces.reduce((a, b) => a + b) / paces.length;
    // 선형: y = 100 + (5 - avg) * 25  → avg=5 → 100, avg=7 → 50
    final score = 100 + (5 - avg) * 25;
    return score.clamp(0.0, 100.0);
  }

  /// 최근 [_recentN]회 평균 거리 → 0~100 점.
  /// 10km → 100, 3km → 30, 그 외 선형.
  static double calcEnduranceScore(List<RunningSessionEntity> sessions) {
    final recent = _takeRecent(sessions, _recentN);
    if (recent.isEmpty) return 0;
    final distances =
        recent.where((s) => s.distanceKm > 0).map((s) => s.distanceKm).toList();
    if (distances.isEmpty) return 0;
    final avg = distances.reduce((a, b) => a + b) / distances.length;
    // 선형: y = 30 + (avg - 3) * 10  → avg=3 → 30, avg=10 → 100
    final score = 30 + (avg - 3) * 10;
    return score.clamp(0.0, 100.0);
  }

  /// 최근 [_consistencyDays]일 동안 달린 횟수 / 30 × 100.
  /// 매일 달리면 100. 한 번도 안 달리면 0.
  static double calcConsistencyScore(
    List<RunningSessionEntity> sessions, {
    DateTime? today,
  }) {
    if (sessions.isEmpty) return 0;
    final ref = today ?? DateTime.now();
    final start = DateTime(ref.year, ref.month, ref.day)
        .subtract(const Duration(days: _consistencyDays - 1));
    final count = sessions
        .where((s) =>
            !s.startTime.isBefore(start) &&
            !s.startTime.isAfter(ref.add(const Duration(days: 1))))
        .map((s) => DateTime(
            s.startTime.year, s.startTime.month, s.startTime.day))
        .toSet()
        .length;
    return ((count / _consistencyDays) * 100).clamp(0.0, 100.0);
  }

  static List<RunningSessionEntity> _takeRecent(
      List<RunningSessionEntity> sessions, int n) {
    if (sessions.isEmpty) return const [];
    final sorted = [...sessions]
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return sorted.take(n).toList();
  }
}
