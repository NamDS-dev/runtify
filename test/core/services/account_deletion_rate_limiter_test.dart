import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/account_deletion_rate_limiter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DateTime fakeNow = DateTime(2026, 5, 9, 22);
  AccountDeletionRateLimiter newLimiter() =>
      AccountDeletionRateLimiter(now: () => fakeNow);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeNow = DateTime(2026, 5, 9, 22);
  });

  group('AccountDeletionRateLimiter', () {
    test('초기 상태는 쿨다운 없음', () async {
      final limiter = newLimiter();
      expect(await limiter.remaining('uid'), null);
    });

    test('3회 미만은 쿨다운 없음', () async {
      final limiter = newLimiter();
      await limiter.markSent('uid');
      expect(await limiter.remaining('uid'), null);
      fakeNow = fakeNow.add(const Duration(seconds: 1));
      await limiter.markSent('uid');
      expect(await limiter.remaining('uid'), null);
    });

    test('3회 도달 시 쿨다운 활성', () async {
      final limiter = newLimiter();
      await limiter.markSent('uid');
      fakeNow = fakeNow.add(const Duration(seconds: 1));
      await limiter.markSent('uid');
      fakeNow = fakeNow.add(const Duration(seconds: 1));
      await limiter.markSent('uid');
      final remaining = await limiter.remaining('uid');
      expect(remaining, isNotNull);
      expect(remaining!.inMinutes, lessThanOrEqualTo(5));
    });

    test('윈도우 5분 경과 후 슬롯 회수', () async {
      final limiter = newLimiter();
      await limiter.markSent('uid');
      await limiter.markSent('uid');
      await limiter.markSent('uid');
      // 5분 + 1초 경과
      fakeNow = fakeNow.add(const Duration(minutes: 5, seconds: 1));
      expect(await limiter.remaining('uid'), null);
    });

    test('uid 가 다르면 슬롯 독립', () async {
      final limiter = newLimiter();
      await limiter.markSent('uid-A');
      await limiter.markSent('uid-A');
      await limiter.markSent('uid-A');
      expect(await limiter.remaining('uid-A'), isNotNull);
      expect(await limiter.remaining('uid-B'), null);
    });
  });
}
