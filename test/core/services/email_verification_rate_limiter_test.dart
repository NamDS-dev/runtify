import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/email_verification_cooldown.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DateTime fakeNow = DateTime(2026, 4, 23, 9, 0, 0);
  EmailVerificationCooldown newCooldown() =>
      EmailVerificationCooldown(now: () => fakeNow);

  const uid = 'user_abc_123';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeNow = DateTime(2026, 4, 23, 9, 0, 0);
  });

  group('EmailVerificationCooldown', () {
    test('최초 상태는 쿨다운 없음', () async {
      final cooldown = newCooldown();
      expect(await cooldown.remaining(uid), isNull);
    });

    test('발송 직후는 60초 쿨다운', () async {
      final cooldown = newCooldown();
      await cooldown.markSent(uid);
      final remaining = await cooldown.remaining(uid);
      expect(remaining, isNotNull);
      expect(remaining!.inSeconds, inInclusiveRange(59, 60));
    });

    test('쿨다운 중간(30초 경과)에는 약 30초 남음', () async {
      final cooldown = newCooldown();
      await cooldown.markSent(uid);

      fakeNow = fakeNow.add(const Duration(seconds: 30));
      final remaining = await cooldown.remaining(uid);
      expect(remaining, isNotNull);
      expect(remaining!.inSeconds, inInclusiveRange(29, 30));
    });

    test('쿨다운 완료 후(60초+) 재발송 가능', () async {
      final cooldown = newCooldown();
      await cooldown.markSent(uid);

      fakeNow = fakeNow.add(const Duration(seconds: 61));
      expect(await cooldown.remaining(uid), isNull);
    });

    test('uid가 다르면 쿨다운 독립', () async {
      final cooldown = newCooldown();
      await cooldown.markSent(uid);
      expect(await cooldown.remaining('other_uid'), isNull);
    });
  });
}
