import '../models/user_model.dart';

// Firebase Auth + Firestore 직접 호출하는 레이어 인터페이스
abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithEmail(String email, String password);
  Future<UserModel> signUpWithEmail(
    String email,
    String password,
    String name, {
    bool marketingConsent = false,
  });
  Future<UserModel> signInWithGoogle();
  Future<UserModel> signInWithApple();
  Future<void> signOut();
  Future<UserModel?> getCurrentUser();

  // 비밀번호 재설정 메일 발송
  // 보안: 등록된 이메일 여부와 무관하게 상위 레이어에서 동일 메시지를 표시한다.
  // (FirebaseAuthException user-not-found 를 던져도 상위에서 성공 응답과 동일하게 취급)
  Future<void> sendPasswordResetEmail(String email);

  // 닉네임 사후 변경 (30일 1회, 2026-05-06 정책)
  // - 호출 전 [NicknameChangePolicy.canChange] 와 `NameValidator` / `NicknameAvailability` 검증 통과 필요
  // - 성공 시 users/{uid}.{name, nameNormalized, nameChangedAt} 갱신
  // - 갱신 후 최신 [UserModel] 반환
  Future<UserModel> changeNickname(String uid, String newName);

  // ── 회원 탈퇴 (POLICY § 4, 2026-05-09) ────────────────────────────────────
  // 소프트 삭제 30일 유예 + 6자리 이메일 코드 이중 재인증.
  // 1) 사용자가 "계정 삭제" 클릭 → 1차 비번/소셜 재로그인 (호출부 책임)
  //    → confirmDeletion 호출 전 [requestDeletionCode] 로 코드 발송
  // 2) 사용자가 6자리 코드 입력 → confirmDeletion 으로 검증 + 소프트 삭제 적용

  // 크루 리더 + 멤버 1명+ 시 false 반환 (탈퇴 불가, UI에서 양도 안내)
  // 크루 미가입 / 리더 아님 / 본인만 멤버 시 true
  Future<bool> canRequestDeletion(String uid);

  // 6자리 코드 발송 (Flutter placeholder — 실제 이메일은 Cloud Functions, 출시 전)
  // 반환: 평문 코드 (디버그 모드에서만 의미. 출시 시 Cloud Functions 가 처리)
  Future<String> requestDeletionCode(String uid);

  // 코드 검증 + 소프트 삭제 적용 (deletedAt = now, scheduledHardDeleteAt = now+30일)
  // 코드 검증 실패 시 Exception 발생
  Future<void> confirmDeletion({required String uid, required String code});

  // 30일 내 재로그인 시 사용자 동의로 호출 → deletedAt/scheduledHardDeleteAt = null
  Future<void> recoverAccount(String uid);
}

// Firebase 실제 구현체는 Firebase 연동 시 별도 파일로 구현
// 현재는 데모 모드: AuthMockDataSource 사용 중
// Firebase 연동 시: auth_firebase_datasource.dart 파일 생성 후 교체
