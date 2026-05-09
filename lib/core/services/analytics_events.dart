import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

// Analytics 이벤트 카탈로그 + 발화 헬퍼
//
// 정책:
// - 이벤트명은 enum/상수로 정의해 오타 방지 + 호출부 일관성
// - PII 미수집: 이메일/닉네임은 절대 파라미터로 보내지 않음. uid 만 setUserId 로 분리 등록
// - Firebase 미초기화/플랫폼 미지원 환경에서 throw 방지 — try/catch + debugPrint
//
// Firebase Analytics 이벤트 이름은 영문 소문자 + underscore 권장 (대시/한글 X)
class AnalyticsEvents {
  static const String signUp = 'sign_up';
  static const String login = 'login';
  static const String logout = 'logout';
  static const String emailVerificationSent = 'email_verification_sent';
  static const String passwordResetRequested = 'password_reset_requested';
  static const String runningStarted = 'running_started';
  static const String runningSaved = 'running_saved';
  static const String crewJoined = 'crew_joined';
  static const String crewLeft = 'crew_left';

  // ── 가설 검증 Tier 1 (2026-05-06) ─────────────────────────────────
  // 가설 1: 지역 기반 랭킹 경쟁이 사용자 호기심을 자극하는가
  // 가설 2: 게임화된 캐릭터 성장 경험이 재방문률을 높이는가
  static const String rankingTabOpened = 'ranking_tab_opened';
  static const String rankingViewDwell = 'ranking_view_dwell';
  static const String levelUp = 'level_up';
  static const String timeToNextRun = 'time_to_next_run';
  static const String badgeEarned = 'badge_earned';
  static const String runningCompleted = 'running_completed';

  // ── 회원 탈퇴 (POLICY § 4 / 2026-05-09) ──────────────────────────
  // 이탈률 + 복구율 분석 — Cloud Functions hard delete 전 30일 동안 추적
  static const String accountDeletionRequested = 'account_deletion_requested';
  static const String accountDeletionConfirmed = 'account_deletion_confirmed';
  static const String accountRecovered = 'account_recovered';

  // dwell 시간을 3초 bucket 으로 정규화 (PII 노출 줄이기 + 그룹 분석 친화)
  static int bucketDwellSeconds(int seconds, {int bucketSize = 3}) {
    if (seconds < 0) return 0;
    return (seconds ~/ bucketSize) * bucketSize;
  }

  static FirebaseAnalytics? _instance;

  static FirebaseAnalytics? _safeInstance() {
    if (_instance != null) return _instance;
    try {
      _instance = FirebaseAnalytics.instance;
      return _instance;
    } catch (_) {
      // Firebase 미초기화 (테스트 / 개발 데모) — null 반환 후 발화 스킵
      return null;
    }
  }

  // 안전 발화 — 실패해도 앱 흐름 차단 X
  static Future<void> log(
    String name, {
    Map<String, Object>? params,
  }) async {
    final inst = _safeInstance();
    if (inst == null) return;
    try {
      await inst.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('[Analytics] logEvent($name) failed: $e');
    }
  }

  // 사용자 식별자 설정 (uid). 로그아웃 시 null 전달
  static Future<void> setUserId(String? uid) async {
    final inst = _safeInstance();
    if (inst == null) return;
    try {
      await inst.setUserId(id: uid);
    } catch (e) {
      debugPrint('[Analytics] setUserId failed: $e');
    }
  }
}
