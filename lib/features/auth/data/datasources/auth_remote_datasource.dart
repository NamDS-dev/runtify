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
}

// Firebase 실제 구현체는 Firebase 연동 시 별도 파일로 구현
// 현재는 데모 모드: AuthMockDataSource 사용 중
// Firebase 연동 시: auth_firebase_datasource.dart 파일 생성 후 교체
