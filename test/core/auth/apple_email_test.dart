import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/auth/apple_email.dart';

void main() {
  group('AppleEmail.isHidden', () {
    test('null/빈 이메일은 false', () {
      expect(AppleEmail.isHidden(null), false);
      expect(AppleEmail.isHidden(''), false);
      expect(AppleEmail.isHidden('   '), false);
    });

    test('일반 이메일은 false', () {
      expect(AppleEmail.isHidden('user@runtify.dev'), false);
      expect(AppleEmail.isHidden('foo@gmail.com'), false);
      expect(AppleEmail.isHidden('foo@bar.com'), false);
    });

    test('@privaterelay.appleid.com 도메인은 true', () {
      expect(
        AppleEmail.isHidden('abc123def@privaterelay.appleid.com'),
        true,
      );
      expect(
        AppleEmail.isHidden('user-token@privaterelay.appleid.com'),
        true,
      );
    });

    test('대소문자/공백 무관', () {
      expect(
        AppleEmail.isHidden('User@PrivateRelay.AppleID.COM'),
        true,
      );
      expect(
        AppleEmail.isHidden('  abc@privaterelay.appleid.com  '),
        true,
      );
    });

    test('비슷한 도메인(서브도메인 사칭) 는 false', () {
      // privaterelay.appleid.com.evil.com 같은 사칭 케이스는 endsWith 체크라 차단
      expect(
        AppleEmail.isHidden('abc@fake-privaterelay.appleid.com'),
        false,
      );
      expect(
        AppleEmail.isHidden('abc@privaterelay.appleid.com.evil.com'),
        false,
      );
    });
  });
}
