import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/nickname_change_policy.dart';

void main() {
  final now = DateTime(2026, 5, 7, 12);

  group('NicknameChangePolicy.canChange', () {
    test('lastChangedAt null → true (한 번도 안 바꿈)', () {
      expect(
        NicknameChangePolicy.canChange(lastChangedAt: null, now: now),
        true,
      );
    });

    test('정확히 30일 전 → true (경계값 포함)', () {
      final lastChanged = now.subtract(const Duration(days: 30));
      expect(
        NicknameChangePolicy.canChange(lastChangedAt: lastChanged, now: now),
        true,
      );
    });

    test('29일 23시간 전 → false (경계값 미만)', () {
      final lastChanged =
          now.subtract(const Duration(days: 29, hours: 23));
      expect(
        NicknameChangePolicy.canChange(lastChangedAt: lastChanged, now: now),
        false,
      );
    });

    test('1일 전 → false', () {
      final lastChanged = now.subtract(const Duration(days: 1));
      expect(
        NicknameChangePolicy.canChange(lastChangedAt: lastChanged, now: now),
        false,
      );
    });

    test('365일 전 → true', () {
      final lastChanged = now.subtract(const Duration(days: 365));
      expect(
        NicknameChangePolicy.canChange(lastChangedAt: lastChanged, now: now),
        true,
      );
    });
  });

  group('NicknameChangePolicy.daysUntilChangeable', () {
    test('lastChangedAt null → 0', () {
      expect(
        NicknameChangePolicy.daysUntilChangeable(lastChangedAt: null, now: now),
        0,
      );
    });

    test('1일 전 변경 → 29일 남음', () {
      final lastChanged = now.subtract(const Duration(days: 1));
      expect(
        NicknameChangePolicy.daysUntilChangeable(
            lastChangedAt: lastChanged, now: now),
        29,
      );
    });

    test('29일 전 변경 → 1일 남음', () {
      final lastChanged = now.subtract(const Duration(days: 29));
      expect(
        NicknameChangePolicy.daysUntilChangeable(
            lastChangedAt: lastChanged, now: now),
        1,
      );
    });

    test('30일 전 변경 → 0일 (변경 가능)', () {
      final lastChanged = now.subtract(const Duration(days: 30));
      expect(
        NicknameChangePolicy.daysUntilChangeable(
            lastChangedAt: lastChanged, now: now),
        0,
      );
    });

    test('100일 전 변경 → 0일 (음수 방어)', () {
      final lastChanged = now.subtract(const Duration(days: 100));
      expect(
        NicknameChangePolicy.daysUntilChangeable(
            lastChangedAt: lastChanged, now: now),
        0,
      );
    });
  });
}
