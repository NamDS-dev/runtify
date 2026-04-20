// 비밀번호 복잡도 검증 유틸
// OWASP 권고에 맞춰 brute-force/사전 공격을 완화.
// 가입 시점에만 엄격 적용, 기존 사용자 로그인 호환 위해 로그인 시점엔 기본 체크만.

class PasswordValidator {
  static const int minLength = 8;
  static const int maxLength = 72; // bcrypt 한계(72byte) 및 Firebase 권장 범위

  // 너무 흔해 공격자가 가장 먼저 시도하는 비밀번호 목록 (소문자 기준 비교)
  static const Set<String> _weakPasswords = {
    'password',
    'password1',
    '12345678',
    '123456789',
    'qwerty123',
    'qwertyuiop',
    'abc12345',
    'abcdefgh',
    'runtify1',
    'runtify123',
    'runtify!',
    'iloveyou',
    'welcome1',
    'admin123',
    '00000000',
    '11111111',
  };

  // 가입 시점 복잡도 검증
  // 반환: null = 통과, String = 에러 메시지
  static String? validateForSignUp(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해주세요';
    }

    if (value.length < minLength) {
      return '비밀번호는 $minLength자 이상이어야 합니다';
    }

    if (value.length > maxLength) {
      return '비밀번호는 $maxLength자 이하여야 합니다';
    }

    if (_weakPasswords.contains(value.toLowerCase())) {
      return '너무 흔한 비밀번호입니다. 다른 비밀번호를 사용해주세요';
    }

    final hasLower = value.contains(RegExp(r'[a-z]'));
    final hasUpper = value.contains(RegExp(r'[A-Z]'));
    final hasDigit = value.contains(RegExp(r'[0-9]'));

    if (!hasLower || !hasUpper || !hasDigit) {
      return '영문 대문자, 소문자, 숫자를 각각 1자 이상 포함해야 합니다';
    }

    return null;
  }

  // 로그인 시점 검증 — 기존 사용자 계정 호환을 위해 기본 체크만
  // (Firebase 서버에서 이미 해시된 비밀번호와 비교하므로 클라이언트는 명백한 공백만 차단)
  static String? validateForSignIn(String? value) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해주세요';
    }
    if (value.length < 6) {
      return '비밀번호는 6자 이상이어야 합니다';
    }
    return null;
  }

  // 비밀번호 강도 계산 (0 ~ 4) — UI 표시용
  // 0: 아주 약함 / 1: 약함 / 2: 보통 / 3: 강함 / 4: 매우 강함
  static int strength(String value) {
    if (value.isEmpty) return 0;
    if (_weakPasswords.contains(value.toLowerCase())) return 0;

    var score = 0;
    if (value.length >= minLength) score++;
    if (value.length >= 12) score++;
    if (value.contains(RegExp(r'[a-z]')) && value.contains(RegExp(r'[A-Z]'))) {
      score++;
    }
    if (value.contains(RegExp(r'[0-9]'))) score++;
    if (value.contains(RegExp(r'[^A-Za-z0-9]'))) score++;

    if (score > 4) score = 4;
    return score;
  }

  // 강도 라벨 (UI용)
  static String strengthLabel(int score) {
    switch (score) {
      case 0:
        return '아주 약함';
      case 1:
        return '약함';
      case 2:
        return '보통';
      case 3:
        return '강함';
      case 4:
        return '매우 강함';
      default:
        return '';
    }
  }
}
