import 'package:flutter_riverpod/flutter_riverpod.dart';

// 현재 사용자가 러닝 트래킹 중인지 여부 (전역 상태).
//
// 정책: [POLICY.md § 3] — 러닝 중에는 토큰 갱신 실패로 인한 자동 로그아웃을 차단해 데이터 유실 방지.
//
// 사용 패턴:
// - 러닝 시작 (running_page initState 또는 _stopRun 시작 시점):
//     `ref.read(runningInProgressProvider.notifier).state = true;`
// - 러닝 종료 (저장 완료 후, dispose 또는 _stopRun 끝):
//     `ref.read(runningInProgressProvider.notifier).state = false;`
// - AuthNotifier 의 idTokenChanges 리스너에서 이 값을 읽어 로그아웃 차단 결정
//
// running_page.dart 의 GPS/라이프사이클 영역과 연결되는 hookup 은
// 야간 자동 수정 제약상 사용자 직접 작업 (다음 세션 권장).
final runningInProgressProvider = StateProvider<bool>((ref) => false);
