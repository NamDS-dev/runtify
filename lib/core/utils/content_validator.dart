// 게시글/댓글 등 사용자 입력 텍스트 검증 유틸
// 보안(XSS, 스팸) + 품질(길이, 빈 문자열) 검증

class ContentValidator {
  // 최대 글자수
  static const int maxPostLength = 500;

  // HTML 태그 패턴 (XSS 방지)
  static final RegExp _htmlTagPattern = RegExp(
    r'<\s*\/?\s*(script|iframe|object|embed|form|input|img|link|style|meta|base|svg|math)\b[^>]*>',
    caseSensitive: false,
  );

  // JavaScript 이벤트 핸들러 패턴
  static final RegExp _jsEventPattern = RegExp(
    r'on(click|load|error|mouseover|focus|blur|submit|change)\s*=',
    caseSensitive: false,
  );

  // javascript: URI 패턴
  static final RegExp _jsUriPattern = RegExp(
    r'javascript\s*:',
    caseSensitive: false,
  );

  // URL 패턴 (스팸 감지용)
  static final RegExp _urlPattern = RegExp(
    r'https?://\S+',
    caseSensitive: false,
  );

  // 제어 문자 (탭/줄바꿈 제외)
  static final RegExp _controlCharPattern = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );

  // 게시글 검증 — null이면 통과, String이면 에러 메시지
  static String? validatePost(String content) {
    // 빈 문자열 체크
    if (content.trim().isEmpty) {
      return '내용을 입력해주세요';
    }

    // 최대 글자수
    if (content.length > maxPostLength) {
      return '게시글은 $maxPostLength자까지 입력할 수 있습니다';
    }

    // HTML 태그 차단
    if (_htmlTagPattern.hasMatch(content)) {
      return 'HTML 태그는 사용할 수 없습니다';
    }

    // JS 이벤트 핸들러 차단
    if (_jsEventPattern.hasMatch(content)) {
      return '허용되지 않는 문자가 포함되어 있습니다';
    }

    // javascript: URI 차단
    if (_jsUriPattern.hasMatch(content)) {
      return '허용되지 않는 문자가 포함되어 있습니다';
    }

    // 과도한 URL (3개 초과) — 스팸 방지
    final urlCount = _urlPattern.allMatches(content).length;
    if (urlCount > 3) {
      return '링크는 최대 3개까지 포함할 수 있습니다';
    }

    return null; // 통과
  }

  // 제어 문자 제거 (저장 전 정제)
  static String sanitize(String content) {
    return content.replaceAll(_controlCharPattern, '');
  }
}
