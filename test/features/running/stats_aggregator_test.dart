import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/features/running/domain/entities/running_session_entity.dart';
import 'package:runtify/features/running/domain/services/stats_aggregator.dart';

RunningSessionEntity _session({
  required DateTime startTime,
  required double distanceKm,
  double avgPace = 5.5,
}) =>
    RunningSessionEntity(
      id: 'id-${startTime.millisecondsSinceEpoch}',
      userId: 'u',
      startTime: startTime,
      distanceKm: distanceKm,
      avgPaceMinPerKm: avgPace,
    );

void main() {
  group('StatsSummary.aggregate — 주간', () {
    // 2026-05-05 화요일 기준 (월요일은 5/4)
    final ref = DateTime(2026, 5, 5, 12);

    test('이번 주 외 sessions은 제외', () {
      final summary = StatsSummary.aggregate(
        sessions: [
          _session(startTime: DateTime(2026, 5, 4, 7), distanceKm: 5),
          _session(startTime: DateTime(2026, 4, 28, 7), distanceKm: 10),
        ],
        range: StatsRange.weekly,
        referenceDate: ref,
      );
      expect(summary.totalDistanceKm, 5);
      expect(summary.runCount, 1);
    });

    test('주간 막대는 항상 7개 (월~일)', () {
      final summary = StatsSummary.aggregate(
        sessions: [],
        range: StatsRange.weekly,
        referenceDate: ref,
      );
      expect(summary.bars.length, 7);
      expect(summary.bars.map((b) => b.label).toList(),
          ['월', '화', '수', '목', '금', '토', '일']);
    });

    test('일별 거리 누적', () {
      final summary = StatsSummary.aggregate(
        sessions: [
          _session(startTime: DateTime(2026, 5, 4, 7), distanceKm: 3),
          _session(startTime: DateTime(2026, 5, 4, 19), distanceKm: 2),
          _session(startTime: DateTime(2026, 5, 5, 8), distanceKm: 5),
        ],
        range: StatsRange.weekly,
        referenceDate: ref,
      );
      expect(summary.bars[0].value, 5); // 월
      expect(summary.bars[1].value, 5); // 화
      expect(summary.totalDistanceKm, 10);
    });

    test('평균 페이스는 거리 가중', () {
      final summary = StatsSummary.aggregate(
        sessions: [
          _session(
              startTime: DateTime(2026, 5, 4), distanceKm: 10, avgPace: 5),
          _session(
              startTime: DateTime(2026, 5, 5), distanceKm: 5, avgPace: 7),
        ],
        range: StatsRange.weekly,
        referenceDate: ref,
      );
      // (10*5 + 5*7) / 15 = 5.667
      expect(summary.avgPaceMinPerKm, closeTo(5.667, 0.01));
    });

    test('빈 sessions → 합계 0, 페이스 0', () {
      final summary = StatsSummary.aggregate(
        sessions: [],
        range: StatsRange.weekly,
        referenceDate: ref,
      );
      expect(summary.totalDistanceKm, 0);
      expect(summary.runCount, 0);
      expect(summary.avgPaceMinPerKm, 0);
    });
  });

  group('StatsSummary.aggregate — 월간', () {
    // 2026-05-15 (5월)
    final ref = DateTime(2026, 5, 15);

    test('다른 달 sessions은 제외', () {
      final summary = StatsSummary.aggregate(
        sessions: [
          _session(startTime: DateTime(2026, 5, 3), distanceKm: 5),
          _session(startTime: DateTime(2026, 4, 30), distanceKm: 10),
          _session(startTime: DateTime(2026, 6, 1), distanceKm: 8),
        ],
        range: StatsRange.monthly,
        referenceDate: ref,
      );
      expect(summary.totalDistanceKm, 5);
    });

    test('주차별 거리 분포', () {
      // 5월: 31일. 1주(1~7), 2주(8~14), 3주(15~21), 4주(22~28), 5주(29~31)
      final summary = StatsSummary.aggregate(
        sessions: [
          _session(startTime: DateTime(2026, 5, 1), distanceKm: 5),
          _session(startTime: DateTime(2026, 5, 10), distanceKm: 7),
          _session(startTime: DateTime(2026, 5, 15), distanceKm: 8),
        ],
        range: StatsRange.monthly,
        referenceDate: ref,
      );
      expect(summary.bars[0].value, 5); // 1주
      expect(summary.bars[1].value, 7); // 2주
      expect(summary.bars[2].value, 8); // 3주
      expect(summary.totalDistanceKm, 20);
    });
  });
}
