import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/widgets/verify_email_dialog.dart';

// 이메일 인증 필수 기능의 진입을 가로막는 공통 가드.
//
// 정책: [POLICY.md § 1] — 인증 필수 기능 작동 시 인증 유도 다이얼로그 표시.
// 사용 패턴:
// ```dart
// if (!await requireEmailVerified(context, ref, contextMessage: '...')) return;
// // ... 실제 작업 ...
// ```
//
// 반환값:
// - true  : 사용자가 이미 인증되어 있거나, 다이얼로그에서 인증을 완료함 → 진행
// - false : 사용자가 미인증 상태로 다이얼로그를 닫음 (또는 로그인 안 됨) → 차단
//
// 인증 상태 판정 우선순위:
// 1. authProvider 의 UserEntity.emailVerified (Firestore 캐시 기준)
// 2. (캐시가 false 라도) Firebase Auth.reload 후 true 가 되면 통과
//
// 다이얼로그 내부에서 사용자가 "인증 완료했어요" 버튼을 누를 때 자체적으로 reload + sync 를 수행하므로
// 이 함수는 다이얼로그 결과(true/false)를 그대로 반환한다.
Future<bool> requireEmailVerified(
  BuildContext context,
  WidgetRef ref, {
  String contextMessage = '이 기능을 사용하려면',
}) async {
  final user = ref.read(authProvider).valueOrNull;
  if (user == null) {
    // 비로그인 상태 — 가드 호출은 의미 없으므로 차단
    return false;
  }
  if (user.emailVerified) return true;

  // 미인증 → 공통 다이얼로그 노출
  final result = await VerifyEmailDialog.show(
    context,
    contextMessage: contextMessage,
  );
  return result == true;
}
