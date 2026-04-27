import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/email_verification_rate_limiter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DateTime fakeNow = DateTime(2026, 4, 24, 9, 0, 0);
  EmailVerificationRateLimiter newLimiter() =>
      EmailVerificationRateLimiter(now: () => fakeNow);

  const uid = 'user_abc_123';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeNow = DateTime(2026, 4, 24, 9, 0, 0);
  });

  group('EmailVerificationRateLimiter (슬라이딩 윈도우 5분/3회)', () {
    test('최초 상태는 잠금 없음', () async {
      final limiter = newLimiter();
      expect(await limiter.remaining(uid), isNull);
    });

    test('1~2회 발송은 잠금 없음', () async {
      final limiter = newLimiter();
      await limiter.markSent(uid);
      fakeNow = fakeNow.add(const Duration(seconds: 10));
      await limiter.markSent(uid);
      expect(await limiter.remaining(uid), isNull);
    });

    test('3회 발송 후는 잠금 — 가장 오래된 발송 기준 5분 잔여', () async {
      final limiter = newLimiter();
      // 세 번의 발송이 각각 30초 간격으로 이뤄짐
      await limiter.markSent(uid); // t=0
      fakeNow = fakeNow.add(const Duration(seconds: 30));
      await limiter.markSent(uid); // t=30
      fakeNow = fakeNow.add(const Duration(seconds: 30));
      await limiter.markSent(uid); // t=60

      // 현재 t=60, 가장 오래된 발송(t=0) + 5분 = t=300 → 240초 남음
      final remaining = await limiter.remaining(uid);
      expect(remaining, isNotNull);
      expect(remaining!.inSeconds, inInclusiveRange(239, 240));
    });

    test('가장 오래된 슬롯만 만료되면 재발송 1회 허용 + 즉시 재잠금', () async {
      final limiter = newLimiter();
      await limiter.markSent(uid); // t=0
      fakeNow = fakeNow.add(const Duration(seconds: 30));
      await limiter.markSent(uid); // t=30
      fakeNow = fakeNow.add(const Duration(seconds: 30));
      await limiter.markSent(uid); // t=60
      expect(await limiter.remaining(uid), isNotNull);

      // t=60 에서 241초 추가 → t=301. t=0 슬롯은 만료, t=30/t=60 은 아직 윈도우 내
      fakeNow = fakeNow.add(const Duration(seconds: 241));
      expect(await limiter.remaining(uid), isNull);

      // 4회째 발송 → 윈도우 내 [30, 60, 301] = 3개 → 다시 잠금
      await limiter.markSent(uid);
      expect(await limiter.remaining(uid), isNotNull);
    });

    test('uid가 다르면 슬롯 독립', () async {
      final limiter = newLimiter();
      await limiter.markSent(uid);
      await limiter.markSent(uid);
      await limiter.markSent(uid);
      expect(await limiter.remaining(uid), isNotNull);
      expect(await limiter.remaining('other_uid'), isNull);
    });

    test('윈도우 완전 경과 후에는 모든 슬롯 회수', () async {
      final limiter = newLimiter();
      await limiter.markSent(uid);
      await limiter.markSent(uid);
      await limiter.markSent(uid);

      // 5분+ 경과 → 3개 슬롯 모두 만료
      fakeNow = fakeNow.add(const Duration(minutes: 6));
      expect(await limiter.remaining(uid), isNull);
    });
  });
}
