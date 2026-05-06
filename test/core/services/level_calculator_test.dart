import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/level_calculator.dart';

void main() {
  group('LevelCalculator.expRequiredForLevelUp', () {
    test('Lv.1 → 2 = 100', () {
      expect(LevelCalculator.expRequiredForLevelUp(1), 100);
    });
    test('Lv.2 → 3 = 150', () {
      expect(LevelCalculator.expRequiredForLevelUp(2), 150);
    });
    test('Lv.5 → 6 = 506', () {
      expect(LevelCalculator.expRequiredForLevelUp(5), 506);
    });
    test('Lv.10 → 11 = 3844', () {
      expect(LevelCalculator.expRequiredForLevelUp(10), 3844);
    });
    test('잘못된 레벨(0/-1)은 기본값 100', () {
      expect(LevelCalculator.expRequiredForLevelUp(0), 100);
      expect(LevelCalculator.expRequiredForLevelUp(-1), 100);
    });
  });

  group('LevelCalculator.totalExpToReachLevel', () {
    test('Lv.1 도달 = 0', () {
      expect(LevelCalculator.totalExpToReachLevel(1), 0);
    });
    test('Lv.2 도달 = 100', () {
      expect(LevelCalculator.totalExpToReachLevel(2), 100);
    });
    test('Lv.3 도달 = 250 (100 + 150)', () {
      expect(LevelCalculator.totalExpToReachLevel(3), 250);
    });
    test('Lv.4 도달 = 475 (100 + 150 + 225)', () {
      expect(LevelCalculator.totalExpToReachLevel(4), 475);
    });
  });

  group('LevelCalculator.levelFromTotalExp', () {
    test('0 EXP → Lv.1', () {
      expect(LevelCalculator.levelFromTotalExp(0), 1);
    });
    test('99 EXP → Lv.1', () {
      expect(LevelCalculator.levelFromTotalExp(99), 1);
    });
    test('정확히 100 EXP → Lv.2', () {
      expect(LevelCalculator.levelFromTotalExp(100), 2);
    });
    test('200 EXP → Lv.2 (Lv.3 까지 250 필요)', () {
      expect(LevelCalculator.levelFromTotalExp(200), 2);
    });
    test('정확히 250 EXP → Lv.3', () {
      expect(LevelCalculator.levelFromTotalExp(250), 3);
    });
    test('474 EXP → Lv.3', () {
      expect(LevelCalculator.levelFromTotalExp(474), 3);
    });
    test('475 EXP → Lv.4', () {
      expect(LevelCalculator.levelFromTotalExp(475), 4);
    });
    test('음수 → Lv.1', () {
      expect(LevelCalculator.levelFromTotalExp(-1), 1);
    });
  });

  group('LevelCalculator.expIntoCurrentLevel', () {
    test('Lv.2 진입 직후 — into = 0', () {
      expect(LevelCalculator.expIntoCurrentLevel(100, 2), 0);
    });
    test('Lv.2 + 50 EXP — into = 50', () {
      expect(LevelCalculator.expIntoCurrentLevel(150, 2), 50);
    });
    test('totalExp 가 base 보다 작으면 0', () {
      expect(LevelCalculator.expIntoCurrentLevel(50, 2), 0);
    });
  });

  group('LevelCalculator.progressToNextLevel', () {
    test('Lv.2 + 75/150 = 0.5', () {
      // 100(Lv.2 base) + 75 = 175 totalExp, Lv.2→3 필요 150 → 75/150 = 0.5
      expect(
        LevelCalculator.progressToNextLevel(175, 2),
        closeTo(0.5, 0.001),
      );
    });
    test('정확히 다음 레벨 도달 직전 — 0.99', () {
      // Lv.1 + 99 EXP / 100 = 0.99
      expect(LevelCalculator.progressToNextLevel(99, 1), closeTo(0.99, 0.001));
    });
    test('clamp — 초과 진입은 1.0 (saveSession 트랜잭션 race 방어)', () {
      expect(LevelCalculator.progressToNextLevel(99999, 1), 1.0);
    });
  });
}
