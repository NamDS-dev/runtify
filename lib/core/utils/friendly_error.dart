// Object/Exception 을 한국어 사용자 친화 메시지로 변환
//
// 패턴 매칭으로 흔한 케이스(네트워크 / 권한 / 타임아웃)를 분기.
// 매치 안되면 generic "잠시 후 다시 시도해주세요" 로 폴백 — 원본 stack trace 노출 방지.
String friendlyErrorMessage(Object error) {
  final msg = error.toString().toLowerCase();

  if (msg.contains('socketexception') ||
      msg.contains('network') ||
      msg.contains('connection') ||
      msg.contains('unreachable')) {
    return '네트워크 연결을 확인한 뒤 다시 시도해주세요';
  }

  if (msg.contains('timeout') || msg.contains('timed out')) {
    return '응답이 너무 늦어요. 잠시 후 다시 시도해주세요';
  }

  if (msg.contains('permission') || msg.contains('permission-denied')) {
    return '권한이 없어 작업을 완료할 수 없어요';
  }

  if (msg.contains('not-found') || msg.contains('not found')) {
    return '요청한 데이터를 찾을 수 없어요';
  }

  if (msg.contains('failed-precondition') || msg.contains('index')) {
    // Firestore 인덱스 미생성 / 미배포 등
    return '서버 설정을 준비 중이에요. 잠시 후 다시 시도해주세요';
  }

  if (msg.contains('unavailable')) {
    return '서비스가 일시적으로 불안정해요. 잠시 후 다시 시도해주세요';
  }

  return '잠시 후 다시 시도해주세요';
}
