import 'package:cloud_firestore/cloud_firestore.dart';

// 개인 최고 기록(PB) 추적 서비스
//
// 정책: 1km / 5km / 10km / 하프(21.0975km) / 풀(42.195km) 5종 거리에 대해
// 사용자가 해당 거리 이상 달린 세션이면 그 거리를 정확히 달리는 데 걸린 (추정) 시간을 계산해
// 기존 PB 와 비교해 갱신 여부 판단.
//
// 추정 방식: 평균 페이스 기반
// - actualTime / actualDistance × pbDistance = 해당 거리 추정 시간
// - 즉 일정한 페이스로 달렸다고 가정 (구간별 페이스가 있으면 더 정확하나 MVP는 평균)
//
// Firestore: `users/{uid}/personal_records/{distanceKey}` 서브컬렉션
//   - distanceKey: '1k' / '5k' / '10k' / 'half' / 'full'
//   - distanceM: int (정확한 거리 m)
//   - bestTimeSeconds: int (추정 시간)
//   - sessionId: 갱신을 만든 세션 ID
//   - achievedAt: timestamp
class PersonalRecordService {
  final FirebaseFirestore _firestore;

  PersonalRecordService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // 거리별 카탈로그 — 키 + 표시 이름 + 정확한 m
  static const List<PrDistance> distances = [
    PrDistance(key: '1k', label: '1km', meters: 1000),
    PrDistance(key: '5k', label: '5km', meters: 5000),
    PrDistance(key: '10k', label: '10km', meters: 10000),
    PrDistance(key: 'half', label: '하프', meters: 21097),
    PrDistance(key: 'full', label: '풀', meters: 42195),
  ];

  // 세션이 통과하는 모든 PB 거리에 대해 갱신 시도.
  // 반환: 갱신된 PrDistance 목록 (결과 페이지 배너 표시용)
  Future<List<PrDistance>> checkAndUpdate({
    required String userId,
    required String sessionId,
    required double sessionDistanceKm,
    required int sessionDurationSeconds,
    required DateTime achievedAt,
  }) async {
    final sessionMeters = sessionDistanceKm * 1000;
    if (sessionMeters <= 0 || sessionDurationSeconds <= 0) return const [];

    final updated = <PrDistance>[];
    for (final pr in distances) {
      // 세션이 해당 PB 거리만큼 달렸어야 함
      if (sessionMeters < pr.meters) continue;

      // 평균 페이스로 해당 거리 시간 추정
      final estimatedSeconds =
          (sessionDurationSeconds * pr.meters / sessionMeters).round();
      if (estimatedSeconds <= 0) continue;

      final didUpdate = await _tryUpdateRecord(
        userId: userId,
        pr: pr,
        candidateSeconds: estimatedSeconds,
        sessionId: sessionId,
        achievedAt: achievedAt,
      );
      if (didUpdate) updated.add(pr);
    }
    return updated;
  }

  // 단일 PB 갱신 시도 — 트랜잭션으로 동시성 보장
  Future<bool> _tryUpdateRecord({
    required String userId,
    required PrDistance pr,
    required int candidateSeconds,
    required String sessionId,
    required DateTime achievedAt,
  }) async {
    final ref = _recordRef(userId, pr.key);
    return _firestore.runTransaction<bool>((tx) async {
      final snap = await tx.get(ref);
      final existingBest = snap.data()?['bestTimeSeconds'] as int?;
      if (existingBest != null && existingBest <= candidateSeconds) {
        return false;
      }
      tx.set(ref, {
        'distanceKey': pr.key,
        'distanceM': pr.meters,
        'bestTimeSeconds': candidateSeconds,
        'sessionId': sessionId,
        'achievedAt': achievedAt.toIso8601String(),
      }, SetOptions(merge: true));
      return true;
    });
  }

  // 사용자의 모든 PB 조회 (프로필 표시용)
  Future<List<PersonalRecord>> getAll(String userId) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('personal_records')
        .get();
    final byKey = {for (final d in snap.docs) d.id: d.data()};
    return [
      for (final pr in distances)
        if (byKey.containsKey(pr.key))
          PersonalRecord(
            distance: pr,
            bestTimeSeconds: (byKey[pr.key]!['bestTimeSeconds'] as int?) ?? 0,
            sessionId: byKey[pr.key]!['sessionId'] as String?,
            achievedAt: _parseDate(byKey[pr.key]!['achievedAt']),
          ),
    ];
  }

  DocumentReference<Map<String, dynamic>> _recordRef(String userId, String key) =>
      _firestore
          .collection('users')
          .doc(userId)
          .collection('personal_records')
          .doc(key);

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return DateTime.tryParse(raw);
    try {
      return (raw as dynamic).toDate() as DateTime?;
    } catch (_) {
      return null;
    }
  }
}

class PrDistance {
  final String key;
  final String label;
  final int meters;

  const PrDistance({
    required this.key,
    required this.label,
    required this.meters,
  });
}

class PersonalRecord {
  final PrDistance distance;
  final int bestTimeSeconds;
  final String? sessionId;
  final DateTime? achievedAt;

  const PersonalRecord({
    required this.distance,
    required this.bestTimeSeconds,
    required this.sessionId,
    required this.achievedAt,
  });

  // "MM:SS" 또는 "H:MM:SS" 포맷
  String get formattedTime {
    final h = bestTimeSeconds ~/ 3600;
    final m = (bestTimeSeconds % 3600) ~/ 60;
    final s = bestTimeSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) return '$h:$mm:$ss';
    return '$mm:$ss';
  }
}
