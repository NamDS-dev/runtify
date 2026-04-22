import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/login_rate_limiter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 가상 시계 — 각 테스트에서 now를 원하는 값으로 고정
  DateTime fakeNow = DateTime(2026, 4, 23, 9, 0, 0);

  setUp(() async {
    // 각 테스트에서 SharedPreferences 초기화 (Mock은 InMemory)
    SharedPreferences.setMockInitialValues({});
    fakeNow = DateTime(2026, 4, 23, 9, 0, 0);
  });

  LoginRateLimiter newLimiter() => LoginRateLimiter(now: () => fakeNow);

  const email = 'user@runtify.dev';

  group('LoginRateLimiter', () {
    test('최초 상태는 잠금 아님', () async {
      final limiter = newLimiter();
      expect(await limiter.lockRemaining(email), isNull);
    });

    test('3회 미만 실패는 잠금 안 걸림', () async {
      final limiter = newLimiter();
      await limiter.recordFailure(email);
      await limiter.recordFailure(email);
      expect(await limiter.lockRemaining(email), isNull);
    });

    test('3회 실패 시 60초 잠금', () async {
      final limiter = newLimiter();
      await limiter.recordFailure(email);
      await limiter.recordFailure(email);
      await limiter.recordFailure(email);

      final remaining = await limiter.lockRemaining(email);
      expect(remaining, isNotNull);
      expect(remaining!.inSeconds, inInclusiveRange(59, 60));
    });

    test('잠금 만료 후에는 잠금 해제 + 카운터 정리', () async {
      final limiter = newLimiter();
      await limiter.recordFailure(email);
      await limiter.recordFailure(email);
      await limiter.recordFailure(email);

      // 시계를 61초 뒤로 이동
      fakeNow = fakeNow.add(const Duration(seconds: 61));
      expect(await limiter.lockRemaining(email), isNull);
    });

    test('성공 시 카운터/잠금 즉시 리셋', () async {
      final limiter = newLimiter();
      await limiter.recordFailure(email);
      await limiter.recordFailure(email);
      await limiter.recordFailure(email);
      expect(await limiter.lockRemaining(email), isNotNull);

      await limiter.resetOnSuccess(email);
      expect(await limiter.lockRemaining(email), isNull);

      // 리셋 후 다시 3회 실패해야 잠금
      await limiter.recordFailure(email);
      await limiter.recordFailure(email);
      expect(await limiter.lockRemaining(email), isNull);
      await limiter.recordFailure(email);
      expect(await limiter.lockRemaining(email), isNotNull);
    });

    test('서로 다른 이메일은 독립 카운터', () async {
      final limiter = newLimiter();
      const other = 'another@runtify.dev';

      await limiter.recordFailure(email);
      await limiter.recordFailure(email);
      await limiter.recordFailure(email);

      expect(await limiter.lockRemaining(email), isNotNull);
      expect(await limiter.lockRemaining(other), isNull);
    });

    test('이메일 정규화 — 대소문자/공백 차이는 동일 카운터', () async {
      final limiter = newLimiter();

      await limiter.recordFailure('User@Runtify.DEV');
      await limiter.recordFailure('  user@runtify.dev  ');
      await limiter.recordFailure('USER@RUNTIFY.DEV');

      // 3회 누적 → 잠금 발생해야 함
      expect(await limiter.lockRemaining(email), isNotNull);
    });
  });
}
