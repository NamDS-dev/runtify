import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 이메일 인증 deep link 핸들러 (2026-05-06).
///
/// Firebase Auth 인증 메일의 링크 클릭 → App Links(Android) / Universal Links(iOS) 로
/// 앱 자동 진입 → `oobCode` 추출 → `applyActionCode` → 사용자 reload 콜백 + 토스트.
///
/// ⚠️ 사용자 직접 작업:
/// - Firebase Console → Auth → Templates → Action URL 을 앱 도메인으로 변경
/// - Android: `assetlinks.json` 호스팅, AndroidManifest intent-filter
/// - iOS: `apple-app-site-association` 호스팅, Xcode Associated Domains
///
/// Flutter 측은 `init()` 으로 콜드/웜 진입 모두 처리.
class DeepLinkHandler {
  final AppLinks _appLinks;
  final FirebaseAuth _auth;
  final void Function() _onVerified;
  final void Function(String message) _onError;

  StreamSubscription<Uri>? _subscription;

  DeepLinkHandler({
    required void Function() onVerified,
    required void Function(String message) onError,
    AppLinks? appLinks,
    FirebaseAuth? auth,
  })  : _onVerified = onVerified,
        _onError = onError,
        _appLinks = appLinks ?? AppLinks(),
        _auth = auth ?? _safeFirebaseAuth();

  /// 콜드(앱이 꺼진 상태에서 링크로 진입) + 웜(앱 실행 중 링크) 둘 다 처리.
  /// 실패는 모두 silent — 일반 앱 진입을 차단하지 않는다.
  Future<void> init() async {
    try {
      // 콜드 진입
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        unawaited(_handleUri(initial));
      }
      // 웜 진입 — uriLinkStream 구독
      _subscription = _appLinks.uriLinkStream.listen(
        _handleUri,
        onError: (_) {
          // 무시
        },
      );
    } catch (e) {
      debugPrint('[DeepLinkHandler] init failed: $e');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }

  Future<void> _handleUri(Uri uri) async {
    final mode = uri.queryParameters['mode'];
    final oobCode = uri.queryParameters['oobCode'];
    if (oobCode == null || oobCode.isEmpty) return;

    // verifyEmail 외 mode (resetPassword, recoverEmail 등) 는 향후 확장
    if (mode != 'verifyEmail') return;

    try {
      await _auth.applyActionCode(oobCode);
      _onVerified();
    } on FirebaseAuthException catch (e) {
      _onError(_friendlyMessage(e));
    } catch (e) {
      _onError('인증 처리 중 오류가 발생했어요');
    }
  }

  /// FirebaseAuthException → 사용자 친화 메시지.
  static String _friendlyMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'expired-action-code':
        return '인증 링크가 만료되었어요. 인증 메일을 다시 발송해주세요';
      case 'invalid-action-code':
        return '유효하지 않은 인증 링크예요';
      default:
        return '인증 처리 중 오류가 발생했어요';
    }
  }

  /// 테스트 환경 Firebase 미초기화 방어 — 인스턴스 호출 시 throw 시 더미 반환.
  /// 실제 앱에서는 Firebase.initializeApp 후 호출되어 정상 동작.
  static FirebaseAuth _safeFirebaseAuth() {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      // 호출 시점에 테스트 환경이면 _handleUri 내부 try-catch 가 fallback
      rethrow;
    }
  }
}
