import 'package:shared_preferences/shared_preferences.dart';

// 이메일 인증 메일 재발송 레이트 리밋 — 슬라이딩 윈도우
//
// 정책: [POLICY.md § 1]
// - 최근 `window`(기본 5분) 안에 이미 `maxSends`(기본 3) 회 발송했다면 추가 발송 차단
// - 차단 시 남은 Duration은 "가장 오래된 발송 시각 + window - now"
// - 발송 성공 시 타임스탬프 배열에 now 추가, 크기 maxSends 초과 시 가장 오래된 항목 pop
//
// 저장: SharedPreferences 단일 키(uid별)에 타임스탬프를 ',' 구분 문자열로 직렬화.
class EmailVerificationRateLimiter {
  static const Duration defaultWindow = Duration(minutes: 5);
  static const int defaultMaxSends = 3;

  final Duration window;
  final int maxSends;
  final DateTime Function() _now;

  EmailVerificationRateLimiter({
    this.window = defaultWindow,
    this.maxSends = defaultMaxSends,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static String _key(String uid) => 'email_verify_sends_$uid';

  // 윈도우 내 잔여 쿨다운이 있으면 남은 Duration, 아니면 null
  Future<Duration?> remaining(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamps = _read(prefs, uid);
    final now = _now();

    // 윈도우 밖 항목 제거 (읽기 시점에 자연스럽게 청소)
    final fresh = timestamps.where(
      (t) => now.difference(t) < window,
    ).toList();

    // 가지치기 결과가 바뀌었으면 디스크에도 반영
    if (fresh.length != timestamps.length) {
      await _write(prefs, uid, fresh);
    }

    if (fresh.length < maxSends) return null;

    // 가장 오래된 발송 기준으로 남은 시간 계산
    final oldest = fresh.first;
    final unlockAt = oldest.add(window);
    final diff = unlockAt.difference(now);
    return diff.isNegative || diff == Duration.zero ? null : diff;
  }

  // 발송 성공 시 타임스탬프 기록
  Future<void> markSent(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamps = _read(prefs, uid);
    final now = _now();

    // 윈도우 내 항목만 유지 + now 추가
    final fresh = timestamps.where(
      (t) => now.difference(t) < window,
    ).toList()
      ..add(now);

    // 정책상 maxSends 초과는 없어야 하지만 방어적으로 앞쪽 pop
    while (fresh.length > maxSends) {
      fresh.removeAt(0);
    }

    await _write(prefs, uid, fresh);
  }

  // 내부: 저장된 타임스탬프 목록 읽기 (오래된 순)
  List<DateTime> _read(SharedPreferences prefs, String uid) {
    final raw = prefs.getString(_key(uid));
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((s) => int.tryParse(s))
        .whereType<int>()
        .map(DateTime.fromMillisecondsSinceEpoch)
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
    final encoded =
        timestamps.map((t) => t.millisecondsSinceEpoch.toString()).join(',');
    await prefs.setString(_key(uid), encoded);
  }
}
