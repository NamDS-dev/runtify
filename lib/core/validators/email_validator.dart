// 이메일 형식 검증 및 정규화 유틸
// 서버(Firebase) 측과 별도로 클라이언트에서 잘못된 이메일을 조기 차단
// 그리고 모든 이메일 입력을 일관된 소문자/trim 형태로 보관 (대소문자/공백으로 인한 로그인 실패 방지)

class EmailValidator {
  // 간이 RFC 5322 정규식 — 대부분의 실 사용 이메일을 커버하고
  // 명백히 잘못된 형식만 거르는 보수적인 패턴
  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  // 폼 validator — null이면 통과, String이면 에러 메시지
  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '이메일을 입력해주세요';
    }

    final normalized = normalize(value);

    // 길이 제한 — RFC 5321 local part 64 + @ + domain 255
    if (normalized.length > 254) {
      return '이메일이 너무 깁니다';
    }

    if (!_emailPattern.hasMatch(normalized)) {
      return '올바른 이메일 형식이 아닙니다';
    }

    return null;
  }

  // 정규화 — 공백 제거 + 소문자 변환
  // 저장/로그인/회원가입 시 반드시 이 메서드를 거쳐야 함
  static String normalize(String value) {
    return value.trim().toLowerCase();
  }
}
