import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM(푸시 알림) 서비스 — 가설 1 검증 (랭킹 변동 알림, 2026-05-06).
///
/// 분리 원칙:
/// - **Flutter 측 (이 파일)**: 토큰 등록·갱신, `users/{uid}.fcmToken` 저장, 메시지 핸들러
/// - **사용자 직접 작업** (출시 전): Firebase Console FCM 설정, Cloud Functions cron
///   (`매주 월요일 09:00 → 사용자별 랭킹 변동 메시지 발송`), Blaze 요금제, APNS 인증서
///
/// native config (`google-services.json` / `GoogleService-Info.plist`) 도 사용자 직접.
class PushNotificationService {
  // 테스트 환경에서 Firebase 미초기화 시 instance 호출이 throw 함 → lazy 로 처리
  FirebaseMessaging? _messaging;
  FirebaseFirestore? _firestore;

  PushNotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  })  : _messaging = messaging,
        _firestore = firestore;

  FirebaseMessaging? get _safeMessaging {
    if (_messaging != null) return _messaging;
    try {
      _messaging = FirebaseMessaging.instance;
      return _messaging;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _safeFirestore {
    if (_firestore != null) return _firestore;
    try {
      _firestore = FirebaseFirestore.instance;
      return _firestore;
    } catch (_) {
      return null;
    }
  }

  /// 로그인 후 호출 — 토큰 등록 + 메시지 핸들러 연결.
  ///
  /// 권한 요청은 ON으로 진행하되 사용자 거부해도 silent — 알림 없이 계속.
  /// Firebase 미초기화/토큰 발급 실패는 모두 silent (앱 흐름 차단 X).
  Future<void> initForUser(String uid) async {
    if (uid.isEmpty) return;
    final messaging = _safeMessaging;
    if (messaging == null) return; // Firebase 미초기화 (테스트/데모) — silent
    try {
      // 권한 요청 — 거부 시에도 흐름 계속
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // 토큰 발급 + Firestore 저장
      final token = await messaging.getToken();
      if (token != null) {
        await _saveToken(uid, token);
      }

      // 토큰 갱신 시 자동 업데이트
      messaging.onTokenRefresh.listen((newToken) {
        _saveToken(uid, newToken);
      });
    } catch (e) {
      debugPrint('[PushNotificationService] init failed: $e');
    }
  }

  /// 로그아웃 시 호출 — 토큰 삭제 + Firestore에서도 제거.
  Future<void> clearForUser(String uid) async {
    if (uid.isEmpty) return;
    final messaging = _safeMessaging;
    final firestore = _safeFirestore;
    if (messaging == null || firestore == null) return;
    try {
      await messaging.deleteToken();
      await firestore.collection('users').doc(uid).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('[PushNotificationService] clear failed: $e');
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    final firestore = _safeFirestore;
    if (firestore == null) return;
    try {
      await firestore.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[PushNotificationService] saveToken failed: $e');
    }
  }
}
