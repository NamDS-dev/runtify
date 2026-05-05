import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 러닝 중 1km 통과 시 음성 안내 — "N km 통과, 페이스 X분 Y초, 평균 심박수 Z".
///
/// 사용자가 Profile에서 ON/OFF 토글. 설정은 SharedPreferences (디바이스 고유,
/// 무음 모드는 보통 디바이스 단위라 다중 디바이스 동기화 불필요).
class RunningVoiceAnnouncer {
  static const String prefKey = 'voice_announcement_enabled';
  static const bool defaultEnabled = true;

  final FlutterTts _tts;
  bool _initialized = false;

  RunningVoiceAnnouncer({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  Future<void> _initOnce() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (_) {
      // 일부 플랫폼/언어 미지원은 무시 — 기본 설정으로 진행
    }
  }

  /// 1km 통과 안내. 설정 OFF면 즉시 반환.
  /// 음성 출력 실패는 조용히 무시 — 러닝 자체는 계속.
  Future<void> announceKm({
    required int km,
    required double paceMinPerKm,
    required double avgHeartRate,
  }) async {
    if (!await isEnabled()) return;
    try {
      await _initOnce();
      final text = formatAnnouncement(
        km: km,
        paceMinPerKm: paceMinPerKm,
        avgHeartRate: avgHeartRate,
      );
      await _tts.speak(text);
    } catch (_) {
      // TTS 미지원/권한 거부는 무시
    }
  }

  /// 사용자가 종료 화면 진입 등에서 정리 호출.
  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
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

  // ── 텍스트 포맷팅 (단위 테스트 친화) ──────────────────────────────

  /// 안내 문장 생성 — "N km 통과, 페이스 X분 Y초, 평균 심박수 Z bpm".
  /// 페이스 ≤ 0 또는 심박수 ≤ 0 인 부분은 생략.
  static String formatAnnouncement({
    required int km,
    required double paceMinPerKm,
    required double avgHeartRate,
  }) {
    final parts = <String>['$km 킬로미터 통과'];

    if (paceMinPerKm > 0) {
      final m = paceMinPerKm.floor();
      final s = ((paceMinPerKm - m) * 60).round();
      if (s == 0) {
        parts.add('페이스 $m분');
      } else {
        parts.add('페이스 $m분 $s초');
      }
    }

    if (avgHeartRate > 0) {
      parts.add('평균 심박수 ${avgHeartRate.round()}');
    }

    return '${parts.join(', ')}.';
  }
}
