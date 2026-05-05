import '../entities/running_session_entity.dart';

/// 통계 페이지 시간 범위 — 주간 / 월간.
enum StatsRange { weekly, monthly }

/// 막대 그래프 한 개 — (라벨, km).
typedef StatsBar = ({String label, double value});

/// 클라이언트 집계 결과 — 단위 테스트 친화 형태.
class StatsSummary {
  final double totalDistanceKm;
  final int runCount;
  final double avgPaceMinPerKm;
  final List<StatsBar> bars;

  const StatsSummary({
    required this.totalDistanceKm,
    required this.runCount,
    required this.avgPaceMinPerKm,
    required this.bars,
  });

  /// 주간/월간 별 sessions 집계.
  ///
  /// 주간: `referenceDate` 기준 같은 주(월~일) 7개 막대(거리 일별).
  /// 월간: `referenceDate` 기준 같은 달의 주차별 막대(1주차/2주차/...).
  static StatsSummary aggregate({
    required List<RunningSessionEntity> sessions,
    required StatsRange range,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();

    if (range == StatsRange.weekly) {
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      final filtered = sessions.where((s) {
        final d = s.startTime;
        return !d.isBefore(weekStart) &&
            d.isBefore(weekStart.add(const Duration(days: 7)));
      }).toList();

      final bars = <StatsBar>[];
      const labels = ['월', '화', '수', '목', '금', '토', '일'];
      for (int i = 0; i < 7; i++) {
        final day = weekStart.add(Duration(days: i));
        final dayDistance = filtered
            .where((s) =>
                s.startTime.year == day.year &&
                s.startTime.month == day.month &&
                s.startTime.day == day.day)
            .fold(0.0, (acc, s) => acc + s.distanceKm);
        bars.add((label: labels[i], value: dayDistance));
      }
      return _aggregate(filtered: filtered, bars: bars);
    }

    // 월간
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final filtered = sessions.where((s) {
      final d = s.startTime;
      return !d.isBefore(monthStart) && d.isBefore(monthEnd);
    }).toList();

    final daysInMonth = monthEnd.subtract(const Duration(days: 1)).day;
    final weekCount = ((daysInMonth - 1) / 7).ceil() + 1;
    final bars = <StatsBar>[];
    for (int w = 0; w < weekCount; w++) {
      final wStart = w * 7 + 1;
      final wEnd = (wStart + 6) > daysInMonth ? daysInMonth : (wStart + 6);
      final weekDistance = filtered
          .where((s) =>
              s.startTime.day >= wStart && s.startTime.day <= wEnd)
          .fold(0.0, (acc, s) => acc + s.distanceKm);
      bars.add((label: '${w + 1}주', value: weekDistance));
    }
    return _aggregate(filtered: filtered, bars: bars);
  }

  static StatsSummary _aggregate({
    required List<RunningSessionEntity> filtered,
    required List<StatsBar> bars,
  }) {
    final total = filtered.fold(0.0, (acc, s) => acc + s.distanceKm);
    double avgPace = 0;
    if (total > 0) {
      double weighted = 0;
      for (final s in filtered) {
        weighted += s.avgPaceMinPerKm * s.distanceKm;
      }
      avgPace = weighted / total;
    }
    return StatsSummary(
      totalDistanceKm: total,
      runCount: filtered.length,
      avgPaceMinPerKm: avgPace,
      bars: bars,
    );
  }
}
