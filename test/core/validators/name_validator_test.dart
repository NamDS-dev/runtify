import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/validators/name_validator.dart';

void main() {
  group('NameValidator.validate — 기본 규칙', () {
    test('빈/공백 값은 에러', () {
      expect(NameValidator.validate(null), isNotNull);
      expect(NameValidator.validate(''), isNotNull);
      expect(NameValidator.validate('   '), isNotNull);
    });

    test('최소 길이 미달은 에러', () {
      expect(NameValidator.validate('a'), isNotNull);
      expect(NameValidator.validate(' A '), isNotNull);
    });

    test('최대 길이 초과는 에러 (grapheme 기준)', () {
      final tooLong = 'a' * 21;
      expect(NameValidator.validate(tooLong), isNotNull);
    });

    test('제어 문자(NULL/DEL 등) 포함은 에러', () {
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

  group('NameValidator — grapheme 길이', () {
    test('🔥 1자 (단일 emoji는 1 grapheme)', () {
      // 길이 검증: "🔥a" 는 grapheme 2자 → minLength 통과
      expect(NameValidator.validate('🔥a'), isNull);
    });

    test('이모지 + 텍스트 조합은 정상', () {
      expect(NameValidator.validate('러너🔥'), isNull);
      expect(NameValidator.validate('abc🔥def'), isNull);
    });

    test('🔥 단일은 1자라 minLength 미달 에러', () {
      // grapheme 길이 1 < minLength 2
      expect(NameValidator.validate('🔥'), isNotNull);
    });
  });

  group('NameValidator — 욕설 차단', () {
    test('한국어 욕설 직접 포함 차단', () {
      expect(NameValidator.containsBadword('시발놈'), true);
      expect(NameValidator.containsBadword('나는병신'), true);
      expect(NameValidator.containsBadword('미친년이다'), true);
    });

    test('영문 욕설 차단', () {
      expect(NameValidator.containsBadword('fuckRunner'), true);
      expect(NameValidator.containsBadword('SHITrun'), true);
    });

    test('우회 시도 (특수문자 사이) 차단', () {
      // "f-u-c-k" 같은 패턴은 _compactForMatching 으로 'fuck' 로 정규화 후 부분 매치
      expect(NameValidator.containsBadword('f-u-c-k'), true);
      expect(NameValidator.containsBadword('s.h.i.t'), true);
    });

    test('대소문자 무관', () {
      expect(NameValidator.containsBadword('FUCK'), true);
      expect(NameValidator.containsBadword('Fuck'), true);
    });

    test('정상 닉네임은 통과', () {
      expect(NameValidator.containsBadword('러너'), false);
      expect(NameValidator.containsBadword('runner'), false);
      expect(NameValidator.containsBadword('Dave Kim'), false);
    });

    test('validate에서 욕설 포함 시 에러 메시지', () {
      expect(NameValidator.validate('시발러너'), isNotNull);
      expect(NameValidator.validate('FUCKrunner'), isNotNull);
    });
  });

  group('NameValidator — 운영진 사칭 차단', () {
    test('직접 사칭 차단', () {
      expect(NameValidator.isReserved('admin'), true);
      expect(NameValidator.isReserved('관리자'), true);
      expect(NameValidator.isReserved('runtify팀'), true);
      expect(NameValidator.isReserved('운영진'), true);
    });

    test('대소문자 무관', () {
      expect(NameValidator.isReserved('ADMIN'), true);
      expect(NameValidator.isReserved('Admin'), true);
      expect(NameValidator.isReserved('Runtify'), true);
    });

    test('부분 매치 차단 (사칭 우회 방지)', () {
      // "Runtify Crew" 도 차단 — 운영진 사칭 가능성
      expect(NameValidator.isReserved('Runtify Crew'), true);
      expect(NameValidator.isReserved('admin_helper'), true);
    });

    test('일반 사용자 닉네임은 통과', () {
      expect(NameValidator.isReserved('러너'), false);
      expect(NameValidator.isReserved('runner_dave'), false);
      expect(NameValidator.isReserved('Dave Kim'), false);
    });

    test('validate에서 사칭 시 에러', () {
      expect(NameValidator.validate('관리자'), isNotNull);
      expect(NameValidator.validate('runtify팀'), isNotNull);
    });
  });

  group('NameValidator — 숫자만/이모지만 차단', () {
    test('숫자만 닉네임 차단', () {
      expect(NameValidator.validate('12345'), isNotNull);
      expect(NameValidator.validate('999999999'), isNotNull);
    });

    test('숫자+텍스트 조합은 통과', () {
      expect(NameValidator.validate('runner123'), isNull);
      expect(NameValidator.validate('1번러너'), isNull);
    });

    test('이모지만 닉네임 차단', () {
      // 단일 이모지는 길이 검증에서 먼저 걸리지만, 2개 이상이면 이모지만 검증에 걸림
      expect(NameValidator.validate('🔥🔥'), isNotNull);
      expect(NameValidator.validate('🏃🏃🏃'), isNotNull);
    });

    test('이모지+텍스트 조합은 통과', () {
      expect(NameValidator.validate('러너🔥'), isNull);
      expect(NameValidator.validate('🔥dave'), isNull);
    });
  });
}
