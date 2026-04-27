import 'package:characters/characters.dart';

// 닉네임(표시 이름) 검증 및 정규화 유틸
//
// 보안/품질 원칙
// - Firestore에 제어 문자·과도한 공백·비정상적 길이 이름이 저장되지 않도록 차단
//   → 랭킹/크루 목록 UI 렌더 깨짐, 스팸성 ID 예방
// - 정규화는 `trim` + 내부 다중 공백 단일화까지만 수행 (언어별 소문자 변환은 하지 않음)
//
// 추가 규칙 (2026-04-28):
// - 길이는 `String.characters.length` (grapheme cluster) 기준 — 🔥 이모지 1자 카운트
// - 욕설/비속어 차단 (소문자 + 공백/특수문자 제거 후 부분 매치)
// - 운영진 사칭 차단 (관리자/runtify팀 등)
// - 숫자만 / 이모지만 닉네임 차단
//
// 욕설·예약 단어 리스트는 코드에 임베드. 운영 중 동적 보강 필요해질 시 assets/JSON으로 이관.
//
// Firestore 중복 검사(`nameNormalized` 쿼리)는 본 sync validator의 책임 밖 — 별도 비동기 서비스에서 처리 예정.

class NameValidator {
  static const int minLength = 2;
  static const int maxLength = 20;

  // 욕설/비속어 (대표 표본 — 향후 운영 중 보강).
  // 정규화(소문자 + 공백/특수문자 제거)된 입력에 부분 매치되면 차단.
  // 보수적으로 명백한 표현만 포함. 무해한 단어가 부분 매치로 차단되지 않도록 신중히 추가.
  static const List<String> _badwords = <String>[
    '시발', '씨발', 'ㅅㅂ', 'ㅆㅂ',
    '병신', 'ㅄ', 'ㅂㅅ',
    '좆', '좃', 'ㅈ같',
    '개새끼', '개섹기',
    '미친놈', '미친년',
    '존나', 'ㅈㄴ',
    '꺼져',
    'fuck', 'shit', 'bitch', 'asshole', 'cunt',
  ];

  // 운영진 사칭 차단 — 정규화 후 부분/완전 매치 모두 차단
  static const List<String> _reserved = <String>[
    'admin', '관리자', '운영자', '운영진', '운영팀',
    'system', '시스템', '공지', '공지사항',
    'runtify', 'runtify팀', '런티파이', '런티파이팀',
    'support', '고객센터', '고객지원', '문의',
    'anthropic', 'claude',
    'official', '공식',
  ];

  // 숫자만 매치 (한자 숫자 제외, ASCII 0-9만)
  static final RegExp _onlyDigits = RegExp(r'^[0-9]+$');

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

    // grapheme cluster 기준 길이 — 🔥, 가족 이모지 등 결합문자도 1자로 카운트
    final graphemeLength = normalized.characters.length;
    if (graphemeLength < minLength) {
      return '닉네임은 $minLength자 이상이어야 합니다';
    }
    if (graphemeLength > maxLength) {
      return '닉네임은 $maxLength자 이하여야 합니다';
    }

    if (_onlyDigits.hasMatch(normalized)) {
      return '닉네임에 글자를 포함해주세요';
    }

    if (_isOnlyEmoji(normalized)) {
      return '닉네임에 텍스트를 포함해주세요';
    }

    if (containsBadword(normalized)) {
      return '사용할 수 없는 단어가 포함되어 있습니다';
    }

    if (isReserved(normalized)) {
      return '사용할 수 없는 닉네임입니다';
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

  // 욕설 매치 — 정규화(소문자 + 공백/특수문자 제거) 후 부분 매치
  static bool containsBadword(String input) {
    final compact = _compactForMatching(input);
    if (compact.isEmpty) return false;
    for (final word in _badwords) {
      final compactWord = _compactForMatching(word);
      if (compactWord.isEmpty) continue;
      if (compact.contains(compactWord)) return true;
    }
    return false;
  }

  // 운영진 사칭 매치 — 정규화 후 부분 매치 (admin, 관리자, runtify팀 등)
  static bool isReserved(String input) {
    final compact = _compactForMatching(input);
    if (compact.isEmpty) return false;
    for (final word in _reserved) {
      final compactWord = _compactForMatching(word);
      if (compactWord.isEmpty) continue;
      if (compact.contains(compactWord)) return true;
    }
    return false;
  }

  // 매칭 전용 정규화 — 소문자 + 공백/특수문자 제거 (영문·숫자·한글만 남김)
  // 사용자가 "a d m i n" / "ad-min" 같이 우회하려는 패턴을 방어
  static String _compactForMatching(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9가-힣ㄱ-ㅎㅏ-ㅣ]'), '');
  }

  // 입력 전체가 이모지 grapheme 으로만 구성됐는지
  // grapheme 단위로 순회하며 ASCII printable / 한글 / 라틴 문자 등이 하나라도 있으면 false
  static bool _isOnlyEmoji(String value) {
    if (value.isEmpty) return false;
    for (final grapheme in value.characters) {
      if (_isTextLikeGrapheme(grapheme)) return false;
    }
    return true;
  }

  // 텍스트성 grapheme 여부 — 영문/숫자/한글/한자 등 일반 문자
  // (이모지·기호류는 false 반환)
  static bool _isTextLikeGrapheme(String grapheme) {
    for (final code in grapheme.runes) {
      // 영문 대소문자
      if ((code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A)) {
        return true;
      }
      // 숫자
      if (code >= 0x30 && code <= 0x39) return true;
      // 한글 음절 / 자모
      if (code >= 0xAC00 && code <= 0xD7A3) return true;
      if (code >= 0x1100 && code <= 0x11FF) return true;
      if (code >= 0x3130 && code <= 0x318F) return true;
      // CJK 통합 한자
      if (code >= 0x4E00 && code <= 0x9FFF) return true;
      // 기본 라틴 확장 (가나/카타카나 등)
      if (code >= 0x3040 && code <= 0x30FF) return true;
    }
    return false;
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
