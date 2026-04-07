// 배지 Firestore 데이터소스 — 배지 조건 체크 + 저장/조회
// Phase 6: 배지 & 칭호 시스템

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/badge_entity.dart';
import '../../domain/entities/running_session_entity.dart';

class BadgeFirestoreDatasource {
  final FirebaseFirestore _firestore;

  BadgeFirestoreDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ── 유저의 획득 배지 목록 조회 ──────────────────────────────────
  Stream<List<EarnedBadge>> watchEarnedBadges(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('badges')
        .orderBy('earnedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EarnedBadge.fromFirestore(doc.data()))
            .toList());
  }

  // ── 런닝 저장 후 배지 달성 조건 체크 ──────────────────────────
  // 반환: 새로 획득한 배지 ID 목록
  Future<List<String>> checkAndAwardBadges({
    required String userId,
    required RunningSessionEntity session,
    required int newStreak, // saveSession에서 계산된 스트릭
    required double newTotalDistance, // 업데이트된 총 거리
  }) async {
    // 1. 이미 획득한 배지 목록 가져오기
    final existingSnap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('badges')
        .get();
    final existingIds = existingSnap.docs.map((d) => d.id).toSet();

    final newBadges = <String>[];

    // 2. 각 배지 조건 체크 (이미 획득한 건 스킵)

    // 🔥 불꽃 러너: 7일 연속 런닝
    if (!existingIds.contains(BadgeIds.streakRunner) && newStreak >= 7) {
      newBadges.add(BadgeIds.streakRunner);
    }

    // 🌙 새벽 러너: 오전 6시 이전 런닝 10회
    if (!existingIds.contains(BadgeIds.earlyRunner)) {
      final earlyCount = await _countEarlyRuns(userId);
      // 현재 세션도 6시 이전이면 +1
      final currentIsEarly = session.startTime.hour < 6;
      if (earlyCount + (currentIsEarly ? 1 : 0) >= 10) {
        newBadges.add(BadgeIds.earlyRunner);
      }
    }

    // ⚡ 스피드 마스터: 페이스 4'30"/km 이하로 5km 이상 완주
    if (!existingIds.contains(BadgeIds.speedMaster)) {
      if (session.distanceKm >= 5.0 && session.avgPaceMinPerKm <= 4.5) {
        newBadges.add(BadgeIds.speedMaster);
      }
    }

    // 🏙️ 지역 지킴이: 구 월간 랭킹 1위 (MVP에서는 스킵 — Cloud Functions 필요)
    // TODO: 월말 집계 시 체크

    // 🗺️ 원정대: 5개 이상 다른 구에서 런닝
    if (!existingIds.contains(BadgeIds.explorer)) {
      final uniqueGus = await _countUniqueRegions(userId);
      if (uniqueGus >= 5) {
        newBadges.add(BadgeIds.explorer);
      }
    }

    // 💯 100km 클럽: 누적 100km 달성
    if (!existingIds.contains(BadgeIds.club100km) && newTotalDistance >= 100.0) {
      newBadges.add(BadgeIds.club100km);
    }

    // 3. 새 배지 저장
    for (final badgeId in newBadges) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .doc(badgeId)
          .set(EarnedBadge(
            badgeId: badgeId,
            earnedAt: DateTime.now(),
          ).toFirestore());
    }

    return newBadges;
  }

  // ── 헬퍼: 새벽 런닝 횟수 (6시 이전 시작) ──────────────────────
  Future<int> _countEarlyRuns(String userId) async {
    // 전체 세션에서 startTime.hour < 6 인 것 카운트
    // Firestore에서 시간 필터링이 어렵기 때문에 클라이언트에서 필터링
    final snap = await _firestore
        .collection('running_sessions')
        .where('userId', isEqualTo: userId)
        .get();

    int count = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final startTime = data['startTime'];
      if (startTime != null) {
        final dt = (startTime as Timestamp).toDate();
        if (dt.hour < 6) count++;
      }
    }
    return count;
  }

  // ── 헬퍼: 유니크 구 개수 ────────────────────────────────────
  Future<int> _countUniqueRegions(String userId) async {
    final snap = await _firestore
        .collection('running_sessions')
        .where('userId', isEqualTo: userId)
        .get();

    final uniqueGus = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      // rankingRegionGu 우선, 없으면 regionGu
      final gu = (data['rankingRegionGu'] as String?) ??
          (data['regionGu'] as String?) ??
          '';
      if (gu.isNotEmpty) uniqueGus.add(gu);
    }
    return uniqueGus.length;
  }
}
