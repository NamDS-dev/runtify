import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/analytics_events.dart';
import '../models/running_session_model.dart';
import 'badge_firestore_datasource.dart';
import 'running_mock_datasource.dart';

// Firestore 기반 러닝 데이터소스
class RunningFirestoreDataSource implements RunningDataSource {
  final FirebaseFirestore _firestore;

  RunningFirestoreDataSource({required FirebaseFirestore firestore})
      : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _sessionsRef =>
      _firestore.collection('running_sessions');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _crewsRef =>
      _firestore.collection('crews');

  // 지역 계층형 랭킹 통계 컬렉션
  CollectionReference<Map<String, dynamic>> get _regionStatsRef =>
      _firestore.collection('regionStats');

  // 최근 러닝 세션 목록 조회 (최신순, 최대 20개)
  @override
  Future<List<RunningSessionModel>> getRecentSessions(String userId) async {
    final snapshot = await _sessionsRef
        .where('userId', isEqualTo: userId)
        .orderBy('startTime', descending: true)
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => RunningSessionModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  // 특정 연/월의 전체 세션 조회 (캘린더 탭에서 사용)
  // startTime을 ISO 문자열로 저장하므로 문자열 범위 쿼리로 필터링
  @override
  Future<List<RunningSessionModel>> getSessionsByMonth(
      String userId, int year, int month) async {
    // 해당 월의 시작/끝 날짜 (ISO 문자열 범위 비교)
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 1).toIso8601String();

    final snapshot = await _sessionsRef
        .where('userId', isEqualTo: userId)
        .where('startTime', isGreaterThanOrEqualTo: startDate)
        .where('startTime', isLessThan: endDate)
        .orderBy('startTime', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => RunningSessionModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  // 러닝 세션 저장 + 유저 통계 + 스트릭 + 포인트 공식 + 크루 포인트 (트랜잭션)
  @override
  Future<RunningSessionModel> saveSession(RunningSessionModel session) async {
    // 배지 체크용 변수 (트랜잭션 내부에서 캡처)
    int capturedStreak = 0;
    double capturedTotalDistance = 0;

    await _firestore.runTransaction((transaction) async {
      final sessionRef = _sessionsRef.doc(session.id);
      final userRef = _usersRef.doc(session.userId);

      // 이미 저장된 세션이면 스킵 (중복 동기화 시 포인트 중복 방지)
      final existingSession = await transaction.get(sessionRef);
      if (existingSession.exists) return;

      // 유저 현재 데이터 조회
      final userDoc = await transaction.get(userRef);
      final userData = userDoc.data() ?? {};

      final currentExp = (userData['experience'] ?? 0) as int;
      final currentStreak = (userData['streak'] ?? 0) as int;
      final currentTotalDistance = (userData['totalDistance'] ?? 0.0) as double;
      final crewId = userData['crewId'] as String?;

      // ── 스트릭 계산 ────────────────────────────────────────────
      // lastRunDate: 마지막 러닝 날짜 (날짜만 비교, 시간 무시)
      DateTime? lastRunDate;
      final rawDate = userData['lastRunDate'];
      if (rawDate != null) {
        if (rawDate is String) {
          lastRunDate = DateTime.tryParse(rawDate);
        } else {
          lastRunDate = (rawDate as Timestamp).toDate();
        }
      }

      final today = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      int newStreak = currentStreak;

      if (lastRunDate == null) {
        // 첫 러닝
        newStreak = 1;
      } else {
        final lastRunDay = DateTime(
          lastRunDate.year,
          lastRunDate.month,
          lastRunDate.day,
        );
        final dayDiff = today.difference(lastRunDay).inDays;

        if (dayDiff == 0) {
          // 오늘 이미 달렸음 → 스트릭 변화 없음
          newStreak = currentStreak;
        } else if (dayDiff == 1) {
          // 어제 달렸음 → 연속 +1
          newStreak = currentStreak + 1;
        } else {
          // 하루 이상 공백 → 스트릭 리셋
          newStreak = 1;
        }
      }

      // ── 포인트 계산 공식 ────────────────────────────────────────
      // 기본: 1km = 10P
      double basePoints = session.distanceKm * 10;

      // 속도 보너스: 평균 페이스 5'00"/km 이하 → +5P/km
      if (session.avgPaceMinPerKm > 0 && session.avgPaceMinPerKm <= 5.0) {
        basePoints += session.distanceKm * 5;
      }

      // 스트릭 보너스 배율 (새로 계산된 streak 기준)
      final multiplier = newStreak >= 7
          ? 1.5
          : newStreak >= 3
              ? 1.2
              : 1.0;

      final finalPoints = (basePoints * multiplier).round();
      final finalExp = finalPoints; // EXP = 포인트와 동일

      // ── 레벨 재계산 ─────────────────────────────────────────────
      final newExp = currentExp + finalExp;
      final newLevel = (newExp ~/ 100) + 1;

      // ── 러닝 세션 저장 (보정된 포인트로 덮어씀) ─────────────────
      final sessionData = session.toFirestore()
        ..['pointsEarned'] = finalPoints
        ..['expEarned'] = finalExp;
      transaction.set(sessionRef, sessionData);

      // ── 유저 통계 업데이트 ───────────────────────────────────────
      // 기본 통계 필드 (항상 업데이트)
      final userUpdateData = <String, dynamic>{
        'totalDistance': FieldValue.increment(session.distanceKm),
        'experience': FieldValue.increment(finalExp),
        'points': FieldValue.increment(finalPoints),
        'level': newLevel,
        'streak': newStreak,
        'lastRunDate': today.toIso8601String(),
      };

      // 지역 계층 필드 — 런닝 GPS 기준으로 유저 현재 지역 업데이트
      // 랭킹 화면의 "내 지역" 배너 표시용 (homeRegion 미설정 시 최신 런닝 기준 사용)
      if (session.regionGu != null && session.regionGu!.isNotEmpty) {
        userUpdateData['regionGu'] = session.regionGu;
      }
      if (session.regionSi != null && session.regionSi!.isNotEmpty) {
        userUpdateData['regionSi'] = session.regionSi;
      }
      if (session.regionDong != null && session.regionDong!.isNotEmpty) {
        userUpdateData['regionDong'] = session.regionDong;
      }

      transaction.update(userRef, userUpdateData);

      // 배지 체크용 값 캡처 (트랜잭션 외부에서 사용)
      capturedStreak = newStreak;
      capturedTotalDistance = currentTotalDistance + session.distanceKm;

      // ── 크루 포인트 연동 (크루에 가입된 경우) ────────────────────
      if (crewId != null && crewId.isNotEmpty) {
        final crewRef = _crewsRef.doc(crewId);
        transaction.update(crewRef, {
          'crewPoints': FieldValue.increment(finalPoints),
          // 이번 달 월간 포인트 (랭킹 화면에서 사용)
          'monthlyPoints': FieldValue.increment(finalPoints),
        });

        // ── 위클리 챌린지 progress 업데이트 ──────────────────────
        // 트랜잭션 외부에서 처리 (Firestore 트랜잭션 내 서브컬렉션 집계 제한 우회)
        // 별도 비동기 작업으로 실행 (세션 저장 완료 후 처리)
        _updateActiveChallenges(
          crewId: crewId,
          userId: session.userId,
          distanceKm: session.distanceKm,
          sessionDate: session.startTime,
        );
      }

      // ── 지역 계층형 랭킹 통계 업데이트 ──────────────────────────
      // rankingRegion 기준으로 통계 업데이트 (없으면 geoRegion fallback)
      // rankingRegion: 홈 지역 우선 / 사용자 컨펌 후 설정 가능
      final statDong = session.rankingRegionDong ?? session.regionDong;
      final statGu = session.rankingRegionGu ?? session.regionGu;
      final statSi = session.rankingRegionSi ?? session.regionSi;

      // 이번 달 연/월 문자열 (예: "2025-03")
      final month =
          '${session.startTime.year}-${session.startTime.month.toString().padLeft(2, '0')}';

      // dong(동) 레벨 통계 — statDong이 있을 때만
      if (statDong != null && statDong.isNotEmpty) {
        final dongRef = _regionStatsRef
            .doc('dong_${statDong}_$month');
        transaction.set(dongRef, {
          'level': 'dong',
          'region': statDong,
          'parentRegion': statGu, // 상위 지역: 구/군
          'month': month,
          'totalPoints': FieldValue.increment(finalPoints),
          'runnerCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }

      // gu(구/군) 레벨 통계 — statGu가 있을 때만
      if (statGu != null && statGu.isNotEmpty) {
        final guRef = _regionStatsRef
            .doc('gu_${statGu}_$month');
        transaction.set(guRef, {
          'level': 'gu',
          'region': statGu,
          'parentRegion': statSi, // 상위 지역: 시·도
          'month': month,
          'totalPoints': FieldValue.increment(finalPoints),
          'runnerCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }

      // si(시·도) 레벨 통계 — statSi가 있을 때만
      if (statSi != null && statSi.isNotEmpty) {
        final siRef = _regionStatsRef
            .doc('si_${statSi}_$month');
        transaction.set(siRef, {
          'level': 'si',
          'region': statSi,
          'parentRegion': null, // 최상위 레벨 — 부모 없음
          'month': month,
          'totalPoints': FieldValue.increment(finalPoints),
          'runnerCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
    });

    // ── 배지 달성 조건 체크 (트랜잭션 외부, 비동기) ────────────────
    // 세션 저장 실패 시 badge 체크 안 됨 (정상 동작)
    try {
      final badgeDatasource = BadgeFirestoreDatasource(firestore: _firestore);
      final newBadgeIds = await badgeDatasource.checkAndAwardBadges(
        userId: session.userId,
        session: session,
        newStreak: capturedStreak,
        newTotalDistance: capturedTotalDistance,
      );
      // 새로 획득한 배지 ID를 세션에 임시 저장 (결과 화면에서 팝업 표시용)
      if (newBadgeIds.isNotEmpty) {
        session = session.copyWithNewBadges(newBadgeIds);
      }
    } catch (_) {
      // 배지 체크 실패해도 러닝 저장에 영향 없음
    }

    // Analytics — 러닝 저장 성공 시점에 발화 (Firebase 호출 실패해도 silent)
    AnalyticsEvents.log(
      AnalyticsEvents.runningSaved,
      params: {
        'distance_km': session.distanceKm,
        'duration_seconds': session.durationSeconds,
      },
    );

    return session;
  }

  // ── 위클리 챌린지 진행률 업데이트 (트랜잭션 외부) ──────────────────────
  // 러닝 세션 저장 성공 후 호출 — active 챌린지별로 타입에 맞게 업데이트
  // unawaited 비동기 처리: 챌린지 업데이트 실패가 러닝 저장에 영향을 주지 않음
  void _updateActiveChallenges({
    required String crewId,
    required String userId,
    required double distanceKm,
    required DateTime sessionDate,
  }) {
    // 비동기로 실행 (await 없음 — 의도적)
    () async {
      try {
        final challengesSnapshot = await _crewsRef
            .doc(crewId)
            .collection('challenges')
            .where('status', isEqualTo: 'active')
            .get();

        if (challengesSnapshot.docs.isEmpty) return;

        // 이번 주 첫 런닝 여부 확인 (participation 챌린지 중복 방지)
        // 이번 주 월요일 00:00 기준
        final now = sessionDate;
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
        final weekEndDay = weekStartDay.add(const Duration(days: 7));

        // 이번 주에 이미 다른 세션이 있는지 확인
        final existingSessions = await _sessionsRef
            .where('userId', isEqualTo: userId)
            .where('startTime', isGreaterThanOrEqualTo: weekStartDay.toIso8601String())
            .where('startTime', isLessThan: weekEndDay.toIso8601String())
            .limit(2) // 현재 세션 포함 2개 조회
            .get();

        // 이미 이번 주에 다른 세션이 있으면 participation 카운트는 증가하지 않음
        // (현재 세션 포함 2개 이상이면 이미 달린 적 있음)
        final isFirstRunThisWeek = existingSessions.docs.length <= 1;

        final batch = _firestore.batch();
        bool hasBatchUpdate = false;

        for (final doc in challengesSnapshot.docs) {
          final data = doc.data();
          final typeStr = data['type'] as String? ?? 'distance';
          final currentValue = (data['currentValue'] as num?)?.toDouble() ?? 0.0;
          final currentParticipant = (data['participantCount'] as num?)?.toInt() ?? 0;
          final targetValue = (data['targetValue'] as num?)?.toDouble() ?? 0.0;

          double newValue = currentValue;
          int newParticipant = currentParticipant;

          switch (typeStr) {
            case 'distance':
              // 합산거리: 모든 크루원 거리 누적
              newValue = currentValue + distanceKm;
              newParticipant = currentParticipant + 1;
              break;
            case 'participation':
              // 참여율: 이번 주 첫 런닝인 경우만 카운트
              if (isFirstRunThisWeek) {
                newParticipant = currentParticipant + 1;
                newValue = newParticipant.toDouble();
              }
              break;
            case 'streak':
              // 연속달리기: 크루 전체 최대 스트릭으로 갱신 (단순화)
              // 실제 스트릭은 user.streak을 조회해 max로 업데이트
              break;
          }

          // 달성 조건 체크
          final isAchieved = newValue >= targetValue;

          batch.update(doc.reference, {
            'currentValue': newValue,
            'participantCount': newParticipant,
            // 달성 시 completed로 변경
            if (isAchieved) 'status': 'completed',
          });
          hasBatchUpdate = true;

          // 챌린지 달성 시 크루원 전원 보너스 포인트 지급
          if (isAchieved) {
            final bonusPoints = (data['bonusPoints'] as num?)?.toInt() ?? 0;
            if (bonusPoints > 0) {
              // 크루 멤버 목록 조회
              final crewDoc = await _crewsRef.doc(crewId).get();
              final memberIds = List<String>.from(
                crewDoc.data()?['memberIds'] as List? ?? [],
              );
              for (final memberId in memberIds) {
                batch.update(_usersRef.doc(memberId), {
                  'points': FieldValue.increment(bonusPoints),
                });
              }
            }
          }
        }

        if (hasBatchUpdate) {
          await batch.commit();
        }
      } catch (e) {
        // 챌린지 업데이트 실패는 무시 (러닝 저장은 이미 성공)
        // 필요 시 로그 시스템 연동 가능
      }
    }();
  }

  // 러닝 세션 삭제
  @override
  Future<void> deleteSession(String sessionId) async {
    await _sessionsRef.doc(sessionId).delete();
  }
}
