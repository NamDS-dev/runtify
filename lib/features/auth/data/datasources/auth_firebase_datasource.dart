import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../../core/validators/email_validator.dart';
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

// Firebase Auth + Firestore 실제 구현체
class AuthFirebaseDataSource implements AuthRemoteDataSource {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthFirebaseDataSource({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  // Firestore users 컬렉션 참조
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  @override
  Future<UserModel> signInWithEmail(String email, String password) async {
    try {
      // 방어적 정규화 — 상위 레이어에서 실수로 trim/lowercase를 놓쳐도 안전
      final normalizedEmail = EmailValidator.normalize(email);
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final uid = credential.user!.uid;
      return await _getUserFromFirestore(uid);
    } on FirebaseAuthException catch (e) {
      throw _convertAuthException(e);
    }
  }

  @override
  Future<UserModel> signUpWithEmail(
    String email,
    String password,
    String name,
  ) async {
    try {
      // 가입 시점부터 정규화된 이메일로 저장해 이후 로그인 매칭 문제 예방
      final normalizedEmail = EmailValidator.normalize(email);

      // Firebase Auth에 계정 생성
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final uid = credential.user!.uid;

      // Firestore에 유저 문서 저장
      final newUser = UserModel(
        id: uid,
        name: name,
        email: normalizedEmail,
        experience: 0,
        points: 0,
        level: 1,
        totalDistance: 0.0,
      );

      await _usersRef.doc(uid).set(newUser.toFirestore());

      return newUser;
    } on FirebaseAuthException catch (e) {
      throw _convertAuthException(e);
    }
  }

  // ── Google 로그인 ──────────────────────────────────────────────────────────
  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      // Google 계정 선택 팝업 표시
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // 사용자가 취소한 경우
        throw Exception('Google 로그인이 취소되었습니다');
      }

      // Google 인증 토큰 가져오기
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase Auth에 Google 자격증명으로 로그인
      final userCredential = await _auth.signInWithCredential(credential);
      final uid = userCredential.user!.uid;

      // Firestore에 유저 문서가 없으면 신규 생성 (최초 소셜 로그인)
      await _createUserIfNotExists(
        uid: uid,
        name: googleUser.displayName ?? '러너',
        email: googleUser.email,
        profileImageUrl: googleUser.photoUrl,
      );

      return await _getUserFromFirestore(uid);
    } on FirebaseAuthException catch (e) {
      throw _convertAuthException(e);
    }
  }

  // ── Apple 로그인 ───────────────────────────────────────────────────────────
  @override
  Future<UserModel> signInWithApple() async {
    try {
      // Apple ID 자격증명 요청
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Firebase OAuthCredential 생성
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Firebase Auth에 Apple 자격증명으로 로그인
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final uid = userCredential.user!.uid;

      // Apple은 최초 로그인 시에만 이름을 제공 → 이후 로그인에서는 null
      final givenName = appleCredential.givenName;
      final familyName = appleCredential.familyName;
      final name = (givenName != null || familyName != null)
          ? '${givenName ?? ''} ${familyName ?? ''}'.trim()
          : null;

      // Firestore에 유저 문서가 없으면 신규 생성
      await _createUserIfNotExists(
        uid: uid,
        name: name ?? userCredential.user?.displayName ?? '러너',
        email: appleCredential.email ?? userCredential.user?.email ?? '',
      );

      return await _getUserFromFirestore(uid);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw Exception('Apple 로그인이 취소되었습니다');
      }
      throw Exception('Apple 로그인 오류: ${e.message}');
    } on FirebaseAuthException catch (e) {
      throw _convertAuthException(e);
    }
  }

  @override
  Future<void> signOut() async {
    // Google 세션도 함께 로그아웃
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      return await _getUserFromFirestore(user.uid);
    } catch (e) {
      return null;
    }
  }

  // ── 공통 헬퍼: Firestore에서 유저 정보 조회 ──────────────────────────────
  Future<UserModel> _getUserFromFirestore(String uid) async {
    final doc = await _usersRef.doc(uid).get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('유저 정보를 찾을 수 없습니다');
    }

    return UserModel.fromFirestore(doc.data()!, uid);
  }

  // ── 공통 헬퍼: Firestore에 유저 문서 없으면 신규 생성 ─────────────────────
  Future<void> _createUserIfNotExists({
    required String uid,
    required String name,
    required String email,
    String? profileImageUrl,
  }) async {
    final doc = await _usersRef.doc(uid).get();
    if (doc.exists) return; // 이미 존재하면 스킵

    final newUser = UserModel(
      id: uid,
      name: name,
      email: email,
      profileImageUrl: profileImageUrl,
      experience: 0,
      points: 0,
      level: 1,
      totalDistance: 0.0,
    );

    await _usersRef.doc(uid).set(newUser.toFirestore());
  }

  // FirebaseAuthException → 한국어 에러 메시지 변환
  // 보안 원칙:
  // - 로그인 실패 시 계정 존재 여부 힌트 차단 (user-not-found/wrong-password 메시지 통일)
  // - 네트워크 에러와 인증 에러를 구분해 재시도 가능 여부를 사용자에게 안내
  Exception _convertAuthException(FirebaseAuthException e) {
    switch (e.code) {
      // ── 로그인 실패 (존재 여부 힌트 제거 통합) ─────────────────────────────
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return Exception('이메일 또는 비밀번호가 올바르지 않습니다');

      // ── 회원가입 관련 ─────────────────────────────────────────────────────
      case 'email-already-in-use':
        return Exception('이미 사용 중인 이메일입니다');
      case 'weak-password':
        return Exception('비밀번호는 6자 이상이어야 합니다');
      case 'invalid-email':
        return Exception('올바른 이메일 형식이 아닙니다');

      // ── 계정 상태 ─────────────────────────────────────────────────────────
      case 'user-disabled':
        return Exception('비활성화된 계정입니다. 고객센터로 문의해주세요');
      case 'user-token-expired':
      case 'requires-recent-login':
        return Exception('세션이 만료되었습니다. 다시 로그인해주세요');

      // ── 레이트 리밋 / 일시 차단 ───────────────────────────────────────────
      case 'too-many-requests':
        return Exception('로그인 시도가 많습니다. 잠시 후 다시 시도해주세요');

      // ── 네트워크 에러 (재시도 가능) ───────────────────────────────────────
      case 'network-request-failed':
        return Exception('네트워크 연결을 확인한 뒤 다시 시도해주세요');

      // ── 인증 방식/제공자 문제 ─────────────────────────────────────────────
      case 'operation-not-allowed':
        return Exception('현재 이 로그인 방식을 사용할 수 없습니다');
      case 'account-exists-with-different-credential':
        return Exception('다른 로그인 방식으로 가입된 이메일입니다');
      case 'credential-already-in-use':
        return Exception('이미 다른 계정에 연결된 인증 정보입니다');

      // ── 비밀번호 재설정 / 이메일 인증 액션 코드 ──────────────────────────
      case 'expired-action-code':
        return Exception('링크가 만료되었습니다. 다시 요청해주세요');
      case 'invalid-action-code':
        return Exception('유효하지 않은 링크입니다');

      // ── 기타 / 알 수 없는 에러 ────────────────────────────────────────────
      default:
        return Exception('오류가 발생했습니다. 잠시 후 다시 시도해주세요');
    }
  }
}
