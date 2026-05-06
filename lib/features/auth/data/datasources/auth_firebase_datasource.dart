import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../../core/auth/apple_email.dart';
import '../../../../core/auth/provider_conflict_message.dart';
import '../../../../core/services/nickname_availability.dart';
import '../../../../core/utils/firebase_timeout.dart';
import '../../../../core/validators/email_validator.dart';
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

// 로그아웃 시 삭제해야 하는 SharedPreferences 키 목록
// 사용자별 데이터(BLE 페어링, 온보딩 완료 상태 등) → 다른 계정 로그인 시 초기화 필요
// 테마는 UI 선호도라 유지 (별도 계정과 무관한 기기 설정)
const List<String> _userScopedPrefsKeys = [
  'ble_device_id',
  'ble_device_name',
  'ble_onboarding_done',
  'health_connect_onboarding_done',
];

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
      final credential = await withFirebaseTimeout(
        _auth.signInWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        ),
        operation: 'signInWithEmail',
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
    String name, {
    bool marketingConsent = false,
  }) async {
    try {
      // 가입 시점부터 정규화된 이메일로 저장해 이후 로그인 매칭 문제 예방
      final normalizedEmail = EmailValidator.normalize(email);

      // Firebase Auth에 계정 생성
      final credential = await withFirebaseTimeout(
        _auth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        ),
        operation: 'signUpWithEmail',
      );

      final uid = credential.user!.uid;

      // 인증 메일 자동 발송 — 실패는 계정 생성을 되돌리지 않음 (UX에서 재발송 제공)
      try {
        await credential.user?.sendEmailVerification();
      } catch (_) {}

      // Firestore에 유저 문서 저장 — 이메일 가입은 미인증 상태로 시작
      // 마케팅 동의는 사용자 선택 → 동의한 경우에만 시점 기록
      // 닉네임 정규화 키는 중복 검사용 — 가입 시점부터 함께 저장
      final now = DateTime.now();
      final newUser = UserModel(
        id: uid,
        name: name,
        email: normalizedEmail,
        experience: 0,
        points: 0,
        level: 1,
        totalDistance: 0.0,
        emailVerified: false,
        marketingConsent: marketingConsent,
        marketingConsentAt: marketingConsent ? now : null,
        nameNormalized: NicknameAvailability.normalizeForKey(name),
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
      // OAuth 가입자는 Google 측에서 이메일이 이미 검증되었으므로 emailVerified: true
      await _createUserIfNotExists(
        uid: uid,
        name: googleUser.displayName ?? '러너',
        email: googleUser.email,
        profileImageUrl: googleUser.photoUrl,
        emailVerified: true,
      );

      return await _getUserFromFirestore(uid);
    } on FirebaseAuthException catch (e) {
      throw await _convertAuthExceptionAsync(e);
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
      // Apple은 ID 토큰 시점에 이메일이 검증된 상태로 제공됨 → emailVerified: true
      // Hide My Email 사용 시 @privaterelay.appleid.com 임시 릴레이 이메일이 들어옴 → appleHiddenEmail: true 표시
      final resolvedEmail =
          appleCredential.email ?? userCredential.user?.email ?? '';
      await _createUserIfNotExists(
        uid: uid,
        name: name ?? userCredential.user?.displayName ?? '러너',
        email: resolvedEmail,
        emailVerified: true,
        appleHiddenEmail: AppleEmail.isHidden(resolvedEmail),
      );

      return await _getUserFromFirestore(uid);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw Exception('Apple 로그인이 취소되었습니다');
      }
      throw Exception('Apple 로그인 오류: ${e.message}');
    } on FirebaseAuthException catch (e) {
      throw await _convertAuthExceptionAsync(e);
    }
  }

  @override
  Future<void> signOut() async {
    // 각 단계가 실패해도 나머지 cleanup은 반드시 수행 — 부분 실패 시 계정 전환이 막히는 일 방지
    // Google 세션 정리 (비-Google 사용자는 no-op 가능하므로 예외 흡수)
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    // Firebase Auth 세션 종료 — 실패해도 로컬 캐시는 지워야 함
    try {
      await _auth.signOut();
    } catch (_) {}

    // 공유 기기에서 이전 사용자 BLE 페어링/온보딩 상태가 노출되지 않도록 사용자 scope 키만 제거
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in _userScopedPrefsKeys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // 입력 방어 — 실수로 trim/lowercase 빠진 값이 와도 일관된 이메일로 요청
      final normalizedEmail = EmailValidator.normalize(email);
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (e) {
      throw _convertAuthException(e);
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final firestoreUser = await _getUserFromFirestore(user.uid);

      // 닉네임 정규화 키 backfill — 기존 사용자 문서에 nameNormalized 부재 시 한 번 채움
      // (가입은 이미 새 필드 포함, 마이그레이션 누락 케이스만 대상)
      if (firestoreUser.nameNormalized == null && firestoreUser.name.isNotEmpty) {
        try {
          await _usersRef.doc(user.uid).update({
            'nameNormalized':
                NicknameAvailability.normalizeForKey(firestoreUser.name),
          });
        } catch (_) {
          // backfill 실패는 회원 흐름을 막지 않음
        }
      }

      // Firebase Auth는 이메일 인증 링크 클릭 후 토큰 갱신 시점에 emailVerified=true가 됨.
      // Firestore 필드가 뒤처져 있으면 즉시 동기화해 이후 호출에서 일관성 확보.
      if (user.emailVerified && !firestoreUser.emailVerified) {
        await _usersRef.doc(user.uid).update({'emailVerified': true});
        return UserModel(
          id: firestoreUser.id,
          name: firestoreUser.name,
          email: firestoreUser.email,
          profileImageUrl: firestoreUser.profileImageUrl,
          experience: firestoreUser.experience,
          points: firestoreUser.points,
          level: firestoreUser.level,
          totalDistance: firestoreUser.totalDistance,
          crewId: firestoreUser.crewId,
          streak: firestoreUser.streak,
          lastRunDate: firestoreUser.lastRunDate,
          homeRegionSi: firestoreUser.homeRegionSi,
          homeRegionGu: firestoreUser.homeRegionGu,
          homeRegionDong: firestoreUser.homeRegionDong,
          emailVerified: true,
        );
      }
      return firestoreUser;
    } catch (e) {
      return null;
    }
  }

  // 닉네임 사후 변경 (30일 1회 정책 — NicknameChangePolicy / 2026-05-06)
  // - 정책 검증/입력 검증/중복 검사는 상위 레이어 책임 — 여기서는 순수 Firestore 갱신만
  // - users/{uid}.{name, nameNormalized, nameChangedAt} 갱신 후 최신 UserModel 반환
  @override
  Future<UserModel> changeNickname(String uid, String newName) async {
    final now = DateTime.now();
    await withFirebaseTimeout(
      _usersRef.doc(uid).update({
        'name': newName,
        'nameNormalized': NicknameAvailability.normalizeForKey(newName),
        'nameChangedAt': now.toIso8601String(),
      }),
      operation: 'changeNickname',
    );
    return await _getUserFromFirestore(uid);
  }

  // 현재 로그인된 사용자에게 이메일 인증 메일을 재발송
  // 쿨다운은 상위 레이어(AuthNotifier)에서 처리 — 여기서는 순수 호출만 담당
  Future<void> sendCurrentUserEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('로그인된 사용자가 없습니다');
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _convertAuthException(e);
    }
  }

  // Firebase Auth의 현재 사용자 인증 상태를 강제 reload 후 Firestore와 동기화
  // 사용자가 "인증 완료했어요" 버튼을 눌렀을 때 호출해 UI 갱신
  Future<bool> reloadAndSyncEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed == null) return false;
    if (refreshed.emailVerified) {
      await _usersRef.doc(refreshed.uid).update({'emailVerified': true});
      return true;
    }
    return false;
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
    bool emailVerified = false,
    bool appleHiddenEmail = false,
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
      emailVerified: emailVerified,
      appleHiddenEmail: appleHiddenEmail,
      nameNormalized: NicknameAvailability.normalizeForKey(name),
    );

    await _usersRef.doc(uid).set(newUser.toFirestore());
  }

  // 비동기 분기 — `account-exists-with-different-credential` 인 경우
  // `fetchSignInMethodsForEmail` 로 기존 가입 방식을 조회해 친절 메시지로 보강.
  // 그 외 케이스는 sync `_convertAuthException` 으로 위임.
  Future<Exception> _convertAuthExceptionAsync(FirebaseAuthException e) async {
    if (e.code == 'account-exists-with-different-credential' &&
        e.email != null &&
        e.email!.isNotEmpty) {
      try {
        // 보안 트레이드오프: Firebase가 fetchSignInMethodsForEmail을
        // email enumeration 방지를 위해 deprecate 했지만, 본 시점에서는
        // 이미 사용자가 자신의 이메일로 사인인을 시도해 provider 충돌이
        // 발생한 상황이라 추가 enumeration 표면이 거의 없다. 친절한 복구
        // 가이드(어느 provider로 가입했는지) 가치가 더 크다고 판단해 유지.
        // 차후 Identity Platform email enumeration protection 활성화 시에는
        // 이 경로를 비활성화하고 generic 메시지로 폴백 필요.
        // ignore: deprecated_member_use
        final methods = await _auth.fetchSignInMethodsForEmail(e.email!);
        return Exception(providerConflictMessage(methods));
      } catch (_) {
        // 조회 실패 시 generic 메시지로 폴백
        return Exception('다른 로그인 방식으로 가입된 이메일입니다');
      }
    }
    return _convertAuthException(e);
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
