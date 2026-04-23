import 'package:shared_preferences/shared_preferences.dart';

// 이메일 인증 메일 재발송 쿨다운 (정책: § 1, 기본 60초)
//
// - 마지막 발송 타임스탬프를 SharedPreferences에 uid별로 저장
// - 쿨다운 중이면 남은 시간 Duration을 반환, 아니면 null
class EmailVerificationCooldown {
  static const Duration defaultCooldown = Duration(seconds: 60);

  final Duration cooldown;
  final DateTime Function() _now;

  EmailVerificationCooldown({
    this.cooldown = defaultCooldown,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static String _key(String uid) => 'email_verify_last_sent_$uid';

  // 쿨다운 중이면 남은 Duration 반환, 아니면 null
  Future<Duration?> remaining(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_key(uid));
    if (lastMs == null) return null;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final elapsed = _now().difference(last);
    if (elapsed >= cooldown) return null;
    return cooldown - elapsed;
  }

  // 발송 완료 시점 기록
  Future<void> markSent(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(uid), _now().millisecondsSinceEpoch);
  }
}
