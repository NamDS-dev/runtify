import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

// FirebaseCrashlytics 안전 호출 헬퍼.
// Firebase 미초기화 / 플랫폼 미지원 (web/desktop) 시 try/catch 로 throw 차단.
class CrashlyticsHelper {
  static FirebaseCrashlytics? _instance;

  static FirebaseCrashlytics? _safeInstance() {
    if (_instance != null) return _instance;
    try {
      _instance = FirebaseCrashlytics.instance;
      return _instance;
    } catch (_) {
      return null;
    }
  }

  // 사용자 식별자 — 로그인 시 uid, 로그아웃 시 빈 문자열
  static Future<void> setUserIdentifier(String identifier) async {
    final inst = _safeInstance();
    if (inst == null) return;
    try {
      await inst.setUserIdentifier(identifier);
    } catch (e) {
      debugPrint('[Crashlytics] setUserIdentifier failed: $e');
    }
  }

  // 비치명 에러 기록 (catch 블록에서 호출)
  static Future<void> recordError(
    Object exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    final inst = _safeInstance();
    if (inst == null) return;
    try {
      await inst.recordError(
        exception,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      debugPrint('[Crashlytics] recordError failed: $e');
    }
  }
}
