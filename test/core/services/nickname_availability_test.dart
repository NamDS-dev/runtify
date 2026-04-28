import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/nickname_availability.dart';

// Firestore 쿼리 경로 자체는 fake_cloud_firestore 같은 새 dev dep 없이 단위 테스트가 어려워
// 이번 야간엔 pure 정규화 헬퍼만 테스트. 통합 검증은 실기기/에뮬레이터 세션에서.
void main() {
  group('NicknameAvailability.normalizeForKey', () {
    test('빈 입력은 빈 문자열', () {
      expect(NicknameAvailability.normalizeForKey(''), '');
      expect(NicknameAvailability.normalizeForKey('   '), '');
    });

    test('대소문자 차이는 동일 키로', () {
      final a = NicknameAvailability.normalizeForKey('Runner');
      final b = NicknameAvailability.normalizeForKey('runner');
      final c = NicknameAvailability.normalizeForKey('RUNNER');
      expect(a, b);
      expect(b, c);
    });

    test('앞뒤 공백 제거 + 내부 다중 공백 단일화', () {
      expect(
        NicknameAvailability.normalizeForKey('  Dave  Kim  '),
        NicknameAvailability.normalizeForKey('dave kim'),
      );
      expect(
        NicknameAvailability.normalizeForKey('Dave\t\tKim'),
        NicknameAvailability.normalizeForKey('dave kim'),
      );
    });

    test('한글 닉네임 정규화', () {
      expect(NicknameAvailability.normalizeForKey('러너'), '러너');
      expect(NicknameAvailability.normalizeForKey('  러너  '), '러너');
    });
  });
}
