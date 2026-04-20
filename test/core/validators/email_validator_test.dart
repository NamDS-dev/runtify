import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/validators/email_validator.dart';

void main() {
  group('EmailValidator.validate', () {
    test('빈 값은 에러', () {
      expect(EmailValidator.validate(null), isNotNull);
      expect(EmailValidator.validate(''), isNotNull);
      expect(EmailValidator.validate('   '), isNotNull);
    });

    test('형식 오류는 에러', () {
      expect(EmailValidator.validate('foo'), isNotNull);
      expect(EmailValidator.validate('foo@'), isNotNull);
      expect(EmailValidator.validate('foo@bar'), isNotNull);
      expect(EmailValidator.validate('@bar.com'), isNotNull);
      expect(EmailValidator.validate('foo bar@baz.com'), isNotNull);
    });

    test('정상 이메일은 통과', () {
      expect(EmailValidator.validate('user@runtify.dev'), isNull);
      expect(EmailValidator.validate('USER@Runtify.DEV'), isNull);
      expect(EmailValidator.validate('  user@runtify.dev  '), isNull);
      expect(EmailValidator.validate('first.last+tag@sub.domain.co.kr'), isNull);
    });

    test('과도하게 긴 이메일은 에러', () {
      final longLocal = 'a' * 250;
      expect(
        EmailValidator.validate('$longLocal@domain.com'),
        isNotNull,
      );
    });
  });

  group('EmailValidator.normalize', () {
    test('공백 제거 + 소문자 변환', () {
      expect(
        EmailValidator.normalize('  User@Runtify.DEV  '),
        'user@runtify.dev',
      );
    });

    test('이미 정규화된 값은 그대로', () {
      expect(
        EmailValidator.normalize('user@runtify.dev'),
        'user@runtify.dev',
      );
    });
  });
}
