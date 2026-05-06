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
    String name, {
    bool marketingConsent = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final newUser = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      experience: 0,
      points: 0,
      level: 1,
      totalDistance: 0.0,
      marketingConsent: marketingConsent,
      marketingConsentAt: marketingConsent ? DateTime.now() : null,
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

  @override
  Future<UserModel> changeNickname(String uid, String newName) async {
    // 데모 모드에서는 메모리 상의 currentUser 만 갱신
    await Future.delayed(const Duration(milliseconds: 200));
    final current = _currentUser;
    if (current == null) {
      throw Exception('로그인 상태를 확인해주세요');
    }
    final updated = UserModel(
      id: current.id,
      name: newName,
      email: current.email,
      profileImageUrl: current.profileImageUrl,
      experience: current.experience,
      points: current.points,
      level: current.level,
      totalDistance: current.totalDistance,
      crewId: current.crewId,
      streak: current.streak,
      lastRunDate: current.lastRunDate,
      homeRegionSi: current.homeRegionSi,
      homeRegionGu: current.homeRegionGu,
      homeRegionDong: current.homeRegionDong,
      emailVerified: current.emailVerified,
      appleHiddenEmail: current.appleHiddenEmail,
      marketingConsent: current.marketingConsent,
      marketingConsentAt: current.marketingConsentAt,
      nameNormalized: newName.toLowerCase(),
      nameChangedAt: DateTime.now(),
    );
    _currentUser = updated;
    return updated;
  }
}
