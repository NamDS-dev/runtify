// 같은 이메일로 다른 provider 가 이미 가입된 경우 친절 메시지 생성
//
// Firebase 의 `fetchSignInMethodsForEmail(email)` 결과 list 를 받아
// 어느 provider 로 가입돼 있는지 한국어로 안내한다.
//
// 우선순위: 소셜(google.com → apple.com) > 이메일/비밀번호.
// (한 이메일에 여러 method 가 연결될 수 있어 가장 사용자가 인지하기 쉬운 하나만 노출)
String providerConflictMessage(List<String> methods) {
  if (methods.contains('google.com')) {
    return '이 이메일은 Google로 가입돼 있어요. Google 로그인을 사용해주세요';
  }
  if (methods.contains('apple.com')) {
    return '이 이메일은 Apple로 가입돼 있어요. Apple 로그인을 사용해주세요';
  }
  if (methods.contains('password')) {
    return '이 이메일은 비밀번호로 가입돼 있어요. 이메일/비밀번호로 로그인해주세요';
  }
  return '다른 로그인 방식으로 가입된 이메일입니다';
}
