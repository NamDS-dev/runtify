import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

// Firebase 없이 동작하는 목업 Auth 데이터소스 (현재 미사용 - Firebase 연동 완료)
class AuthMockDataSource implements AuthRemoteDataSource {
  static const _demoUser = UserModel(
    id: 'demo_user_001',
    name: '데모 러너',
    email: 'demo@runtify.com',
    experience: 1230,
    points: 1230,
    level: 5,
    totalDistance: 87.4,
    crewId: null,
  );

  UserModel? _currentUser = _demoUser;

  @override
  Future<UserModel> signInWithEmail(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _currentUser = _demoUser;
    return _demoUser;
  }

  @override
  Future<UserModel> signUpWithEmail(
    String email,
    String password,
    String name,
  ) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final newUser = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      experience: 0,
      points: 0,
      level: 1,
      totalDistance: 0.0,
    );
    _currentUser = newUser;
    return newUser;
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _currentUser = _demoUser;
    return _demoUser;
  }

  @override
  Future<UserModel> signInWithApple() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _currentUser = _demoUser;
    return _demoUser;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    // 데모 모드에서는 실제 발송 없이 no-op
    await Future.delayed(const Duration(milliseconds: 400));
  }
}
