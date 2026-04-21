// 닉네임(표시 이름) 검증 및 정규화 유틸
//
// 보안/품질 원칙
// - Firestore에 제어 문자·과도한 공백·비정상적 길이 이름이 저장되지 않도록 차단
//   → 랭킹/크루 목록 UI 렌더 깨짐, 스팸성 ID 예방
// - 정규화는 `trim` + 내부 다중 공백 단일화까지만 수행 (언어별 소문자 변환은 하지 않음)

class NameValidator {
  static const int minLength = 2;
  static const int maxLength = 20;

  // 폼 validator — null이면 통과, String이면 에러 메시지
  static String? validate(String? value) {
    if (value == null) return '닉네임을 입력해주세요';

    final normalized = normalize(value);

    if (normalized.isEmpty) {
      return '닉네임을 입력해주세요';
    }

    if (_hasControlCharacter(normalized)) {
      return '사용할 수 없는 문자가 포함되어 있습니다';
    }

    if (normalized.length < minLength) {
      return '닉네임은 $minLength자 이상이어야 합니다';
    }

    if (normalized.length > maxLength) {
      return '닉네임은 $maxLength자 이하여야 합니다';
    }

    return null;
  }

  // 정규화 — 앞뒤 공백 제거 + 내부 다중 공백 단일화
  // 저장 직전 반드시 이 메서드를 통과시켜 Firestore 저장 값 일관성 유지
  static String normalize(String value) {
    final trimmed = value.trim();
    // 다중 공백(스페이스/탭/개행)을 단일 스페이스로 축약
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  // 제어 문자(U+0000~U+001F, U+007F~U+009F) 포함 여부
  // 정규식 이스케이프 대신 코드포인트 순회로 명시적 검사 — 환경에 덜 의존적
  static bool _hasControlCharacter(String value) {
    for (final codeUnit in value.codeUnits) {
      if (codeUnit <= 0x1F) return true;
      if (codeUnit >= 0x7F && codeUnit <= 0x9F) return true;
    }
    return false;
  }
}
