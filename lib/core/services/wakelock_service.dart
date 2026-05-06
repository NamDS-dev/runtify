import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 러닝 중 화면 켜짐 유지 (wakelock_plus, 2026-05-06).
///
/// 알림 권한 거부 시 ForegroundNotificationConfig.enableWakeLock 미적용 → 화면 꺼지면
/// GPS 정확도 저하 가능. wakelock_plus 로 알림 권한 무관하게 보장.
///
/// 디바이스 고유 (SharedPreferences). 사용자 Profile 토글 OFF 시 비활성.
/// 웹은 미지원 → 모든 호출 silent 폴백.
class WakelockService {
  static const String prefKey = 'wakelock_enabled';
  static const bool defaultEnabled = true;

  /// 토글 ON 이면 wakelock 활성. 실패 시 silent.
  Future<void> tryEnable() async {
    if (kIsWeb) return;
    if (!await isEnabled()) return;
    try {
      await WakelockPlus.enable();
    } catch (_) {
      // 미지원 플랫폼 / 권한 / native 에러 — 러닝 자체는 계속
    }
  }

  /// 항상 시도 — 토글 상태와 무관하게 비활성화.
  /// (혹시 사용자가 러닝 중 토글 OFF 한 경우 dispose 시 정리)
  Future<void> tryDisable() async {
    if (kIsWeb) return;
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // 무시
    }
  }

  // ── 토글 영속화 (SharedPreferences) ─────────────────────────────

  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefKey) ?? defaultEnabled;
    } catch (_) {
      return defaultEnabled;
    }
  }

  static Future<void> setEnabled(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, value);
    } catch (_) {
      // 무시
    }
  }
}
