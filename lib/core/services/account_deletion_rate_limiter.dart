import 'package:shared_preferences/shared_preferences.dart';

/// 회원 탈퇴 6자리 코드 발송 레이트 리밋 — 슬라이딩 윈도우 (POLICY § 4 / 2026-05-09).
///
/// 정책: 5분 / 3회 (이메일 인증 재발송 정책과 동일).
/// 사용자가 짧은 시간에 코드를 무한히 발송 요청하는 것을 방지 — Firestore write + 향후 Cloud Functions 이메일 비용 절감.
///
/// 저장: SharedPreferences 단일 키(uid별)에 타임스탬프 ',' 구분 직렬화.
class AccountDeletionRateLimiter {
  static const Duration defaultWindow = Duration(minutes: 5);
  static const int defaultMaxSends = 3;

  final Duration window;
  final int maxSends;
  final DateTime Function() _now;

  AccountDeletionRateLimiter({
    this.window = defaultWindow,
    this.maxSends = defaultMaxSends,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static String _key(String uid) => 'deletion_code_sends_$uid';

  /// 윈도우 내 잔여 쿨다운이 있으면 남은 Duration, 아니면 null.
  Future<Duration?> remaining(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamps = _read(prefs, uid);
    final now = _now();

    // 윈도우 밖 항목 제거
    final fresh = timestamps.where((t) => now.difference(t) < window).toList();
    if (fresh.length != timestamps.length) {
      await _write(prefs, uid, fresh);
    }

    if (fresh.length < maxSends) return null;

    final oldest = fresh.first;
    final unlockAt = oldest.add(window);
    final diff = unlockAt.difference(now);
    return diff.isNegative || diff == Duration.zero ? null : diff;
  }

  /// 발송 성공 시 타임스탬프 기록.
  Future<void> markSent(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamps = _read(prefs, uid);
    final now = _now();

    final fresh = timestamps.where((t) => now.difference(t) < window).toList()
      ..add(now);
    await _write(prefs, uid, fresh);
  }

  // ── 내부 직렬화 ──────────────────────────────────────────────

  List<DateTime> _read(SharedPreferences prefs, String uid) {
    final raw = prefs.getString(_key(uid));
    if (raw == null || raw.isEmpty) return [];
    return raw
        .split(',')
        .map((s) => DateTime.tryParse(s.trim()))
        .whereType<DateTime>()
        .toList();
  }

  Future<void> _write(
    SharedPreferences prefs,
    String uid,
    List<DateTime> timestamps,
  ) async {
    if (timestamps.isEmpty) {
      await prefs.remove(_key(uid));
      return;
    }
    final raw = timestamps.map((t) => t.toIso8601String()).join(',');
    await prefs.setString(_key(uid), raw);
  }
}
