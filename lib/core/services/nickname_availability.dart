import 'package:cloud_firestore/cloud_firestore.dart';
import '../validators/name_validator.dart';

// 닉네임 Firestore 중복 검사 서비스
//
// 정책: 회원가입 폼 sync 검증 → 비동기 중복 검사 → Firebase 가입 순서.
// `users` 컬렉션의 `nameNormalized` 단일 필드 인덱스를 활용한 단순 쿼리.
//
// ⚠️ 인덱스 의존성:
// - 단일 필드 쿼리(`where('nameNormalized', '==', X)`)는 자동 인덱스 대상
// - 하지만 호출 시 인덱스 미생성/생성 중이면 FAILED_PRECONDITION 발생 가능
// - `firestore.indexes.json`에 명시적 단일 필드 인덱스 추가 + `firebase deploy --only firestore:indexes`
//   는 사용자 직접 작업 (야간 PM은 indexes.json 변경 금지)
//
// 결과 (`NicknameAvailabilityResult`):
// - available: 사용 가능
// - taken: 다른 사용자가 이미 사용 중
// - error: 쿼리 실패 (네트워크 / 인덱스 미생성 등) — UI 에서 generic 안내 후 사용자 재시도 유도
class NicknameAvailability {
  final FirebaseFirestore _firestore;

  NicknameAvailability({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // 닉네임 사용 가능 여부 검사
  // - currentUserId 가 주어지면 본인 문서는 매치에서 제외 (같은 닉네임으로 본인이 갱신 시 가능)
  Future<NicknameAvailabilityResult> check(
    String name, {
    String? currentUserId,
  }) async {
    final normalized = _normalizeForKey(name);
    if (normalized.isEmpty) {
      return NicknameAvailabilityResult.available;
    }

    try {
      final snap = await _firestore
          .collection('users')
          .where('nameNormalized', isEqualTo: normalized)
          .limit(2)
          .get();

      // 본인 외 다른 사용자가 동일 닉네임을 사용 중인지
      final hasOtherUser = snap.docs.any((d) => d.id != currentUserId);
      return hasOtherUser
          ? NicknameAvailabilityResult.taken
          : NicknameAvailabilityResult.available;
    } catch (_) {
      return NicknameAvailabilityResult.error;
    }
  }

  // Firestore에 저장할 정규화 키 — `NameValidator.normalize` + 소문자
  // (대소문자 차이는 동일 닉네임으로 취급)
  static String normalizeForKey(String name) => _normalizeForKey(name);

  static String _normalizeForKey(String name) {
    return NameValidator.normalize(name).toLowerCase();
  }
}

enum NicknameAvailabilityResult {
  available,
  taken,
  error,
}
