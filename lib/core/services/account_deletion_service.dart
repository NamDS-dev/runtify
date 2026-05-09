import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../utils/firebase_timeout.dart';

/// 회원 탈퇴 6자리 코드 검증 결과.
/// - tooManyAttempts: 5회 연속 잘못된 코드 입력 → 브루트포스 방지로 코드 자동 무효화
enum DeletionCodeResult { valid, invalid, expired, notIssued, tooManyAttempts }

/// 회원 탈퇴 6자리 인증 코드 서비스 — POLICY § 4 (2026-05-09).
///
/// 분리 원칙:
/// - **Flutter 측 (이 파일)**: 코드 생성 + SHA256 해시 + Firestore subdoc(TTL 10분) 저장 + 검증
/// - **사용자 직접 (Cloud Functions)**: 이메일 발송 (`sendDeletionCodeEmail`), hard delete cron
///
/// ⚠️ 출시 전 보안 강화: 클라이언트가 코드 생성하면 콘솔/메모리에서 추출 가능.
/// 출시 시점에는 Cloud Functions onCall(`requestDeletionCode`)에서 코드 생성·해시·이메일 발송
/// 모두 처리해야 함. 현재 구조는 placeholder + Cloud Functions 마이그레이션 친화 형태.
///
/// Firestore 구조: `users/{uid}/account_deletion/code` 문서
/// - `codeHash`: SHA256(code + uid) hex
/// - `issuedAt`: ISO timestamp
/// - `expiresAt`: issuedAt + 10분
class AccountDeletionService {
  static const Duration codeTtl = Duration(minutes: 10);
  static const int codeLength = 6;
  static const String _docName = 'code';
  // 브루트포스 방지 — 5회 연속 잘못된 코드 입력 시 코드 자동 무효화
  static const int maxAttempts = 5;

  final FirebaseFirestore _firestore;
  final Random _random;

  AccountDeletionService({
    FirebaseFirestore? firestore,
    Random? random,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _random = random ?? Random.secure();

  DocumentReference<Map<String, dynamic>> _codeDoc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('account_deletion')
      .doc(_docName);

  /// 6자리 숫자 코드 생성 + 해시 저장.
  ///
  /// 반환된 평문 코드는 호출부(현재는 디버그 로그, 출시 시 Cloud Functions 이메일 발송)로 전달.
  /// **호출부는 평문 코드를 영속화하면 안 됨.** 메모리에서만 사용 후 사용자 입력 후 [verifyCode] 로 검증.
  Future<String> issueCode({
    required String uid,
    DateTime? now,
  }) async {
    final code = _generateCode();
    final issuedAt = now ?? DateTime.now();
    final expiresAt = issuedAt.add(codeTtl);
    final hash = _hashCodeForUser(code: code, uid: uid);

    await withFirebaseTimeout(
      _codeDoc(uid).set({
        'codeHash': hash,
        'issuedAt': issuedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        // 시도 횟수 — verifyCode 실패 시 increment, maxAttempts 도달 시 doc 삭제
        'attemptCount': 0,
      }),
      operation: 'AccountDeletionService.issueCode',
    );

    // 디버그 빌드에서만 콘솔 출력 (Cloud Functions 이메일 발송 대체)
    // 출시 빌드에서는 절대 출력되지 않음 (kDebugMode false)
    if (kDebugMode) {
      // ignore: avoid_print
      debugPrint('[AccountDeletion] code=$code (debug only, expires ${expiresAt.toIso8601String()})');
    }

    return code;
  }

  /// 사용자 입력 코드를 해시 비교 + TTL 검증 + 브루트포스 시도 횟수 제한.
  ///
  /// 잘못된 코드 입력 시 attemptCount increment. [maxAttempts] 도달 시
  /// 코드 doc 즉시 삭제하고 [DeletionCodeResult.tooManyAttempts] 반환 →
  /// 사용자는 issueCode 부터 다시 시작해야 함.
  Future<DeletionCodeResult> verifyCode({
    required String uid,
    required String code,
    DateTime? now,
  }) async {
    final snap = await withFirebaseTimeout(
      _codeDoc(uid).get(),
      operation: 'AccountDeletionService.verifyCode',
    );
    if (!snap.exists) return DeletionCodeResult.notIssued;
    final data = snap.data()!;

    final expiresAtStr = data['expiresAt'] as String?;
    if (expiresAtStr == null) return DeletionCodeResult.notIssued;
    final expiresAt = DateTime.tryParse(expiresAtStr);
    if (expiresAt == null) return DeletionCodeResult.notIssued;

    final ref = now ?? DateTime.now();
    if (ref.isAfter(expiresAt)) return DeletionCodeResult.expired;

    final expectedHash = data['codeHash'] as String?;
    if (expectedHash == null) return DeletionCodeResult.notIssued;

    final candidateHash = _hashCodeForUser(code: code, uid: uid);
    if (candidateHash == expectedHash) {
      return DeletionCodeResult.valid;
    }

    // 잘못된 코드 — 시도 횟수 증가 + maxAttempts 도달 시 무효화
    final currentAttempts = (data['attemptCount'] as int?) ?? 0;
    final newAttempts = currentAttempts + 1;
    if (newAttempts >= maxAttempts) {
      try {
        await _codeDoc(uid).delete();
      } catch (_) {
        // 무시 — 다음 issueCode 시 덮어쓰기
      }
      return DeletionCodeResult.tooManyAttempts;
    }
    try {
      await _codeDoc(uid).update({'attemptCount': newAttempts});
    } catch (_) {
      // 카운터 갱신 실패는 silent — 사용자 흐름 차단 X
    }
    return DeletionCodeResult.invalid;
  }

  /// 검증 성공/취소 후 코드 문서 정리. 한 번 사용한 코드 재사용 차단.
  Future<void> clearCode(String uid) async {
    try {
      await _codeDoc(uid).delete();
    } catch (_) {
      // 이미 삭제됐거나 미존재 — 무시
    }
  }

  // ── 내부 유틸 (단위 테스트 친화) ────────────────────────────────────

  String _generateCode() {
    final buf = StringBuffer();
    for (int i = 0; i < codeLength; i++) {
      buf.write(_random.nextInt(10));
    }
    return buf.toString();
  }

  /// 해시 입력에 uid 를 섞어 다른 사용자 코드와 충돌/공유 방지.
  static String _hashCodeForUser({required String code, required String uid}) {
    final bytes = utf8.encode('$code:$uid');
    return sha256.convert(bytes).toString();
  }

  /// 단위 테스트용 노출.
  @visibleForTesting
  static String hashCodeForUserForTest({required String code, required String uid}) =>
      _hashCodeForUser(code: code, uid: uid);
}
