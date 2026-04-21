import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/validators/name_validator.dart';

void main() {
  group('NameValidator.validate', () {
    test('빈/공백 값은 에러', () {
      expect(NameValidator.validate(null), isNotNull);
      expect(NameValidator.validate(''), isNotNull);
      expect(NameValidator.validate('   '), isNotNull);
    });

    test('최소 길이 미달은 에러', () {
      expect(NameValidator.validate('a'), isNotNull);
      expect(NameValidator.validate(' A '), isNotNull);
    });

    test('최대 길이 초과는 에러', () {
      final tooLong = 'a' * 21;
      expect(NameValidator.validate(tooLong), isNotNull);
    });

    test('제어 문자(NULL/DEL 등) 포함은 에러', () {
      // U+0000 NULL — 실제 바이트 대신 fromCharCode 로 구성해 소스 파일에 바이너리를 넣지 않음
      final withNull = 'user${String.fromCharCode(0)}name';
      final withUnitSeparator = 'ab${String.fromCharCode(0x1F)}cd';
      final withDel = 'ab${String.fromCharCode(0x7F)}cd';

      expect(NameValidator.validate(withNull), isNotNull);
      expect(NameValidator.validate(withUnitSeparator), isNotNull);
      expect(NameValidator.validate(withDel), isNotNull);
    });

    test('정상 닉네임은 통과', () {
      expect(NameValidator.validate('러닝왕'), isNull);
      expect(NameValidator.validate('Dave Kim'), isNull);
      expect(NameValidator.validate('runner_2026'), isNull);
      expect(NameValidator.validate('  러너 2026  '), isNull);
    });
  });

  group('NameValidator.normalize', () {
    test('앞뒤 공백 제거', () {
      expect(NameValidator.normalize('  Dave  '), 'Dave');
    });

    test('내부 다중 공백은 단일 스페이스로 축약', () {
      expect(NameValidator.normalize('Dave    K    Kim'), 'Dave K Kim');
      expect(NameValidator.normalize('a\t\tb'), 'a b');
      expect(NameValidator.normalize('a\n\nb'), 'a b');
    });

    test('이미 정규화된 값은 그대로', () {
      expect(NameValidator.normalize('러닝왕'), '러닝왕');
    });
  });
}
