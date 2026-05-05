import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/features/running/domain/entities/goal_entity.dart';

void main() {
  group('GoalType.validateInputValue', () {
    test('주간 거리 — 유효 범위', () {
      expect(GoalType.weeklyDistance.validateInputValue(50), null);
      expect(GoalType.weeklyDistance.validateInputValue(200), null);
      expect(GoalType.weeklyDistance.validateInputValue(0), isNotNull);
      expect(GoalType.weeklyDistance.validateInputValue(-5), isNotNull);
      expect(GoalType.weeklyDistance.validateInputValue(201), isNotNull);
      expect(GoalType.weeklyDistance.validateInputValue(9999), isNotNull);
    });

    test('월간 거리 — 상한 800km', () {
      expect(GoalType.monthlyDistance.validateInputValue(800), null);
      expect(GoalType.monthlyDistance.validateInputValue(801), isNotNull);
    });

    test('주간 횟수 — 상한 21회', () {
      expect(GoalType.weeklyCount.validateInputValue(21), null);
      expect(GoalType.weeklyCount.validateInputValue(22), isNotNull);
    });

    test('연속 달리기 — 상한 365일', () {
      expect(GoalType.streak.validateInputValue(365), null);
      expect(GoalType.streak.validateInputValue(366), isNotNull);
    });

    test('상한 초과 메시지에 단위 포함', () {
      final msg = GoalType.weeklyDistance.validateInputValue(500);
      expect(msg, contains('200'));
      expect(msg, contains('km'));
    });

    test('0 또는 음수 메시지', () {
      expect(GoalType.weeklyDistance.validateInputValue(0),
          contains('0보다 큰 값'));
      expect(GoalType.weeklyDistance.validateInputValue(-1),
          contains('0보다 큰 값'));
    });
  });
}
