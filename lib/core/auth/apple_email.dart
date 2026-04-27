// Apple "Hide My Email" 임시 이메일 감지 유틸
//
// Apple Sign In 시 사용자가 Hide My Email 옵션을 선택하면
// `@privaterelay.appleid.com` 도메인의 임시 릴레이 이메일이 발급된다.
// 마케팅 메일 도달성·이메일 변경 안내 등에서 일반 이메일과 구분 처리 필요.
class AppleEmail {
  static const String _hiddenDomain = '@privaterelay.appleid.com';

  // 정규화 후 도메인 매치 — 대소문자 무관
  static bool isHidden(String? email) {
    if (email == null) return false;
    final normalized = email.trim().toLowerCase();
    return normalized.endsWith(_hiddenDomain);
  }
}
