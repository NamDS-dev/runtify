import 'package:shared_preferences/shared_preferences.dart';

// 로그인 실패 레이트 리밋 — Phase 1 (로컬 전용)
//
// 정책: [POLICY.md § 2]
// - 이메일별 실패 횟수를 SharedPreferences에 저장
// - maxAttempts(기본 3회) 도달 시 lockDuration(기본 60초) 잠금
// - 성공 시 카운터 즉시 리셋
//
// 한계(Phase 2에서 보강 예정):
// - 앱 재설치 시 카운터 초기화됨 → 서버 측(Cloud Functions) 강화는 출시 직전 검토
class LoginRateLimiter {
  static const int maxAttempts = 3;
  static const Duration lockDuration = Duration(seconds: 60);

  // SharedPreferences는 내부에서 getInstance() 호출 (캐시되므로 오버헤드 적음).
  // `now`는 테스트 주입용 — 기본은 DateTime.now
  final DateTime Function() _now;

  LoginRateLimiter({DateTime Function()? now}) : _now = now ?? DateTime.now;

  // SharedPreferences 키 — 이메일 정규화 후 hashCode 기반으로 난독화
  // (원본 이메일 문자열을 키로 쓰지 않음. 로컬 dump 대비 방어선)
  static String _countKey(String email) =>
      'login_fail_count_${_keyOf(email)}';
  static String _lockKey(String email) =>
      'login_lock_until_${_keyOf(email)}';

  static String _keyOf(String email) {
    final normalized = email.trim().toLowerCase();
    // 32비트 unsigned hashCode — 충돌은 단일 기기에서 실질 무시 가능
    return normalized.hashCode.toUnsigned(32).toRadixString(36);
  }

  // 현재 잠금 상태의 남은 시간. null = 잠금 아님
  Future<Duration?> lockRemaining(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final untilMs = prefs.getInt(_lockKey(email));
    if (untilMs == null) return null;

    final until = DateTime.fromMillisecondsSinceEpoch(untilMs);
    final diff = until.difference(_now());
    if (diff.isNegative || diff == Duration.zero) {
      // 만료된 잠금은 흔적 제거 (다음 호출부터 빠른 경로)
      await prefs.remove(_lockKey(email));
      await prefs.remove(_countKey(email));
      return null;
    }
    return diff;
  }

  // 로그인 실패 기록. maxAttempts 도달 시 lockDuration 잠금
  Future<void> recordFailure(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final countKey = _countKey(email);
    final next = (prefs.getInt(countKey) ?? 0) + 1;
    await prefs.setInt(countKey, next);

    if (next >= maxAttempts) {
      final until = _now().add(lockDuration);
      await prefs.setInt(_lockKey(email), until.millisecondsSinceEpoch);
    }
  }

  // 로그인 성공 시 카운터/잠금 즉시 리셋 (정책: 단순함 우선)
  Future<void> resetOnSuccess(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_countKey(email));
    await prefs.remove(_lockKey(email));
  }
}
