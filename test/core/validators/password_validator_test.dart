import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/validators/password_validator.dart';

void main() {
  group('PasswordValidator.validateForSignUp', () {
    test('빈 값은 에러', () {
      expect(PasswordValidator.validateForSignUp(null), isNotNull);
      expect(PasswordValidator.validateForSignUp(''), isNotNull);
    });

    test('8자 미만은 에러', () {
      expect(PasswordValidator.validateForSignUp('Ab1xyz'), isNotNull);
    });

    test('흔한 비밀번호는 차단 (대소문자 무관)', () {
      expect(PasswordValidator.validateForSignUp('password'), isNotNull);
      expect(PasswordValidator.validateForSignUp('Password1'), isNotNull); // 목록 매칭은 소문자 기준
      expect(PasswordValidator.validateForSignUp('12345678'), isNotNull);
      expect(PasswordValidator.validateForSignUp('Runtify123'), isNotNull);
    });

    test('대/소/숫자 중 하나라도 빠지면 에러', () {
      expect(PasswordValidator.validateForSignUp('alllowercase1'), isNotNull);
      expect(PasswordValidator.validateForSignUp('ALLUPPERCASE1'), isNotNull);
      expect(PasswordValidator.validateForSignUp('NoDigitsHere'), isNotNull);
    });

    test('복잡도 충족 시 통과', () {
      expect(PasswordValidator.validateForSignUp('Str0ngPass'), isNull);
      expect(PasswordValidator.validateForSignUp('Runt1fyApp'), isNull);
    });

    test('최대 길이 초과 에러', () {
      expect(PasswordValidator.validateForSignUp('Aa1${'x' * 100}'), isNotNull);
    });
  });

  group('PasswordValidator.validateForSignIn', () {
    test('빈 값은 에러', () {
      expect(PasswordValidator.validateForSignIn(null), isNotNull);
      expect(PasswordValidator.validateForSignIn(''), isNotNull);
    });

    test('6자 이상이면 통과 (기존 사용자 호환)', () {
      expect(PasswordValidator.validateForSignIn('123456'), isNull);
      expect(PasswordValidator.validateForSignIn('simplepass'), isNull);
    });

    test('6자 미만은 에러', () {
      expect(PasswordValidator.validateForSignIn('12345'), isNotNull);
    });
  });

  group('PasswordValidator.strength', () {
    test('빈 값과 흔한 비밀번호는 0', () {
      expect(PasswordValidator.strength(''), 0);
      expect(PasswordValidator.strength('password'), 0);
      expect(PasswordValidator.strength('12345678'), 0);
    });

    test('복잡도 높을수록 점수 상승', () {
      final weak = PasswordValidator.strength('abcdefgh');
      final medium = PasswordValidator.strength('Abcdefg1');
      final strong = PasswordValidator.strength('Abcdefgh1!');
      final veryStrong = PasswordValidator.strength('Abcdefghij12!@');

      expect(weak, lessThan(medium));
      expect(medium, lessThanOrEqualTo(strong));
      expect(strong, lessThanOrEqualTo(veryStrong));
      expect(veryStrong, 4);
    });
  });
}
