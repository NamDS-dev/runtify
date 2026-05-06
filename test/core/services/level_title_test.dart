import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/level_title.dart';

void main() {
  group('LevelTitle.forLevel', () {
    test('Lv.1 → 신입 러너', () {
      expect(LevelTitle.forLevel(1), '신입 러너');
    });
    test('Lv.4 → 신입 러너 (Lv.5 미만)', () {
      expect(LevelTitle.forLevel(4), '신입 러너');
    });
    test('Lv.5 → 동네 러너 (경계값 포함)', () {
      expect(LevelTitle.forLevel(5), '동네 러너');
    });
    test('Lv.9 → 동네 러너', () {
      expect(LevelTitle.forLevel(9), '동네 러너');
    });
    test('Lv.10 → 베테랑 러너', () {
      expect(LevelTitle.forLevel(10), '베테랑 러너');
    });
    test('Lv.19 → 베테랑 러너', () {
      expect(LevelTitle.forLevel(19), '베테랑 러너');
    });
    test('Lv.20 → 마스터 러너', () {
      expect(LevelTitle.forLevel(20), '마스터 러너');
    });
    test('Lv.30 → 챔피언 러너', () {
      expect(LevelTitle.forLevel(30), '챔피언 러너');
    });
    test('Lv.50 → 전설의 러너', () {
      expect(LevelTitle.forLevel(50), '전설의 러너');
    });
    test('Lv.99 → 전설의 러너 (최고 칭호 유지)', () {
      expect(LevelTitle.forLevel(99), '전설의 러너');
    });
    test('Lv.0 / 음수 → 신입 러너 (방어)', () {
      expect(LevelTitle.forLevel(0), '신입 러너');
      expect(LevelTitle.forLevel(-5), '신입 러너');
    });
  });

  group('LevelTitle.levelsToNextTitle', () {
    test('Lv.1 → 다음 동네 러너까지 4레벨', () {
      expect(LevelTitle.levelsToNextTitle(1), 4);
    });
    test('Lv.5 → 다음 베테랑 러너까지 5레벨', () {
      expect(LevelTitle.levelsToNextTitle(5), 5);
    });
    test('Lv.10 → 마스터까지 10', () {
      expect(LevelTitle.levelsToNextTitle(10), 10);
    });
    test('Lv.50 (최고 칭호) → null', () {
      expect(LevelTitle.levelsToNextTitle(50), null);
    });
    test('Lv.99 → null', () {
      expect(LevelTitle.levelsToNextTitle(99), null);
    });
  });

  group('LevelTitle.nextTitle', () {
    test('Lv.1 → 동네 러너', () {
      expect(LevelTitle.nextTitle(1), '동네 러너');
    });
    test('Lv.30 → 전설의 러너', () {
      expect(LevelTitle.nextTitle(30), '전설의 러너');
    });
    test('Lv.50 → null', () {
      expect(LevelTitle.nextTitle(50), null);
    });
  });
}
