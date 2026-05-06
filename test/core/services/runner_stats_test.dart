import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/runner_stats.dart';
import 'package:runtify/features/running/domain/entities/running_session_entity.dart';

RunningSessionEntity _s({
  required DateTime startTime,
  double pace = 0,
  double distanceKm = 0,
}) =>
    RunningSessionEntity(
      id: 'id-${startTime.millisecondsSinceEpoch}',
      userId: 'u',
      startTime: startTime,
      avgPaceMinPerKm: pace,
      distanceKm: distanceKm,
    );

void main() {
  group('RunnerStats.calcSpeedScore', () {
    test('빈 sessions → 0', () {
      expect(RunnerStats.calcSpeedScore([]), 0);
    });

    test('페이스 0인 세션은 제외', () {
      final score = RunnerStats.calcSpeedScore([
        _s(startTime: DateTime(2026, 5, 5), pace: 0, distanceKm: 5),
      ]);
      expect(score, 0);
    });

    test('페이스 5.0 → 100점', () {
      final score = RunnerStats.calcSpeedScore([
        _s(startTime: DateTime(2026, 5, 5), pace: 5.0, distanceKm: 5),
      ]);
      expect(score, 100);
    });

    test('페이스 7.0 → 50점', () {
      final score = RunnerStats.calcSpeedScore([
        _s(startTime: DateTime(2026, 5, 5), pace: 7.0, distanceKm: 5),
      ]);
      expect(score, 50);
    });

    test('페이스 6.0 (중간값) → 75점', () {
      final score = RunnerStats.calcSpeedScore([
        _s(startTime: DateTime(2026, 5, 5), pace: 6.0, distanceKm: 5),
      ]);
      expect(score, 75);
    });

    test('clamp — 페이스 4.0 (5.0보다 빠름) → 100점 max', () {
      final score = RunnerStats.calcSpeedScore([
        _s(startTime: DateTime(2026, 5, 5), pace: 4.0, distanceKm: 5),
      ]);
      expect(score, 100);
    });

    test('최근 5회 평균', () {
      final score = RunnerStats.calcSpeedScore([
        for (int i = 0; i < 5; i++)
          _s(startTime: DateTime(2026, 5, 5 - i), pace: 6.0, distanceKm: 5),
        // 6번째는 무시되어야 함
        _s(startTime: DateTime(2026, 4, 1), pace: 4.0, distanceKm: 5),
      ]);
      // 최근 5개는 모두 6.0 → 75
      expect(score, 75);
    });
  });

  group('RunnerStats.calcEnduranceScore', () {
    test('빈 sessions → 0', () {
      expect(RunnerStats.calcEnduranceScore([]), 0);
    });

    test('거리 10km → 100점', () {
      final score = RunnerStats.calcEnduranceScore([
        _s(startTime: DateTime(2026, 5, 5), pace: 5.0, distanceKm: 10),
      ]);
      expect(score, 100);
    });

    test('거리 3km → 30점', () {
      final score = RunnerStats.calcEnduranceScore([
        _s(startTime: DateTime(2026, 5, 5), pace: 5.0, distanceKm: 3),
      ]);
      expect(score, 30);
    });

    test('거리 5km → 50점', () {
      final score = RunnerStats.calcEnduranceScore([
        _s(startTime: DateTime(2026, 5, 5), pace: 5.0, distanceKm: 5),
      ]);
      expect(score, 50);
    });

    test('clamp — 거리 20km → 100점 max', () {
      final score = RunnerStats.calcEnduranceScore([
        _s(startTime: DateTime(2026, 5, 5), pace: 5.0, distanceKm: 20),
      ]);
      expect(score, 100);
    });
  });

  group('RunnerStats.calcConsistencyScore', () {
    final today = DateTime(2026, 5, 5);

    test('빈 sessions → 0', () {
      expect(RunnerStats.calcConsistencyScore([], today: today), 0);
    });

    test('최근 30일 매일 달리면 100', () {
      final sessions = [
        for (int i = 0; i < 30; i++)
          _s(
              startTime: today.subtract(Duration(days: i)),
              pace: 5,
              distanceKm: 5),
      ];
      expect(RunnerStats.calcConsistencyScore(sessions, today: today), 100);
    });

    test('최근 30일 중 15일 달리면 50', () {
      final sessions = [
        for (int i = 0; i < 15; i++)
          _s(
              startTime: today.subtract(Duration(days: i)),
              pace: 5,
              distanceKm: 5),
      ];
      expect(RunnerStats.calcConsistencyScore(sessions, today: today), 50);
    });

    test('30일 윈도우 밖 sessions은 제외', () {
      final sessions = [
        _s(startTime: today, pace: 5, distanceKm: 5),
        // 50일 전은 윈도우 밖
        _s(startTime: today.subtract(const Duration(days: 50)), pace: 5, distanceKm: 5),
      ];
      // 1/30 * 100 ≈ 3.33
      expect(
        RunnerStats.calcConsistencyScore(sessions, today: today),
        closeTo(3.33, 0.01),
      );
    });

    test('하루 여러 번 달려도 1일로 카운트', () {
      final sessions = [
        _s(startTime: DateTime(2026, 5, 5, 7), pace: 5, distanceKm: 5),
        _s(startTime: DateTime(2026, 5, 5, 19), pace: 5, distanceKm: 5),
      ];
      expect(
        RunnerStats.calcConsistencyScore(sessions, today: today),
        closeTo(3.33, 0.01),
      );
    });
  });
}
