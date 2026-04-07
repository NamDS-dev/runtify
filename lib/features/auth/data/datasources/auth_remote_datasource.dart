import '../models/user_model.dart';

// Firebase Auth + Firestore 직접 호출하는 레이어 인터페이스
abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithEmail(String email, String password);
  Future<UserModel> signUpWithEmail(String email, String password, String name);
  Future<UserModel> signInWithGoogle();
  Future<UserModel> signInWithApple();
  Future<void> signOut();
  Future<UserModel?> getCurrentUser();
}

// Firebase 실제 구현체는 Firebase 연동 시 별도 파일로 구현
// 현재는 데모 모드: AuthMockDataSource 사용 중
// Firebase 연동 시: auth_firebase_datasource.dart 파일 생성 후 교체
