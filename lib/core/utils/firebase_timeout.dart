import 'dart:async';

/// Firebase 호출 timeout 헬퍼 (2026-05-06 결정).
///
/// 정책: **모든 Firebase 외부 호출 30초 timeout** (보수적 — 데이터 유실 방지).
/// - read 쿼리(.get/.snapshots)에 적용해 네트워크 끊김 시 무한 hang 방지
/// - **트랜잭션(runTransaction)은 적용 X** — Firestore SDK 자체 retry 정책에 의존
///   (외부 timeout 으로 정상 트랜잭션 retry 가 끊기면 데이터 유실 위험)
///
/// timeout 발생 시 [FirebaseTimeoutException] 으로 변환 — 호출부에서 친절한 메시지 표시 가능.
class FirebaseTimeoutException implements Exception {
  final String operation;
  final Duration duration;

  const FirebaseTimeoutException({
    required this.operation,
    required this.duration,
  });

  @override
  String toString() => 'FirebaseTimeoutException($operation, ${duration.inSeconds}s)';

  /// 사용자 노출용 친절 메시지
  String get userMessage =>
      '서버 응답이 늦어요. 네트워크 상태를 확인하고 다시 시도해주세요.';
}

/// 기본 timeout — 30초.
const Duration defaultFirebaseTimeout = Duration(seconds: 30);

/// Future 에 timeout 적용. timeout 발생 시 [FirebaseTimeoutException] 발생.
///
/// 사용 예:
/// ```dart
/// final docs = await withFirebaseTimeout(
///   _sessionsRef.get(),
///   operation: 'getRecentSessions',
/// );
/// ```
Future<T> withFirebaseTimeout<T>(
  Future<T> future, {
  required String operation,
  Duration timeout = defaultFirebaseTimeout,
}) {
  return future.timeout(
    timeout,
    onTimeout: () =>
        throw FirebaseTimeoutException(operation: operation, duration: timeout),
  );
}
