import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/goal_firestore_datasource.dart';
import '../../data/models/goal_model.dart';
import '../../domain/entities/goal_entity.dart';

// ── 헬퍼: ISO 주차 번호 계산 (ISO 8601 기준) ────────────────────────────────
int _isoWeek(DateTime date) {
  final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
  final weekDay = date.weekday; // 1=월, 7=일
  return ((dayOfYear - weekDay + 10) / 7).floor();
}

// 현재 기간 문자열 생성 (월간: "2026-03", 주간: "2026-W12")
String _currentPeriod({required bool isMonthly}) {
  final now = DateTime.now();
  if (isMonthly) {
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  } else {
    return '${now.year}-W${_isoWeek(now).toString().padLeft(2, '0')}';
  }
}

// ── 이번 주 월요일/일요일 날짜 계산 ──────────────────────────────────────────
DateTime _weekStart(DateTime date) {
  // 이번 주 월요일 00:00:00
  return DateTime(date.year, date.month, date.day - (date.weekday - 1));
}

DateTime _weekEnd(DateTime date) {
  // 이번 주 일요일 23:59:59
  final monday = _weekStart(date);
  return DateTime(
      monday.year, monday.month, monday.day + 6, 23, 59, 59, 999);
}

// ── GoalFirestoreDataSource Provider ──────────────────────────────────────
final goalFirestoreDataSourceProvider =
    Provider<GoalFirestoreDataSource>((ref) {
  return GoalFirestoreDataSource(firestore: FirebaseFirestore.instance);
});

// ── 목표 목록 실시간 스트림 Provider (userId별) ──────────────────────────────
// goals 서브컬렉션 구독 → currentValue를 running_sessions에서 자동 계산 후 반환
final goalsProvider =
    StreamProvider.family<List<GoalEntity>, String>((ref, userId) {
  final now = DateTime.now();
  // 현재 월 period (예: "2026-03")
  final monthPeriod =
      '${now.year}-${now.month.toString().padLeft(2, '0')}';
  // 현재 주 period (예: "2026-W12")
  final weekPeriod =
      '${now.year}-W${_isoWeek(now).toString().padLeft(2, '0')}';

  // goals 서브컬렉션 실시간 구독
  final goalDs = ref.read(goalFirestoreDataSourceProvider);
  return goalDs
      .getGoals(userId)
      .asyncMap((goals) async {
        // 현재 주/월에 해당하는 목표만 필터링
        final filtered = goals
            .where((g) => g.period == monthPeriod || g.period == weekPeriod)
            .toList();

        if (filtered.isEmpty) return <GoalEntity>[];

        // running_sessions에서 이번 달/주 통계를 한 번만 조회
        final sessionsSnap = await FirebaseFirestore.instance
            .collection('running_sessions')
            .where('userId', isEqualTo: userId)
            .get();

        final allSessions = sessionsSnap.docs.map((d) => d.data()).toList();

        // 이번 달 세션 필터링
        final monthStart = DateTime(now.year, now.month, 1);
        final monthEnd = DateTime(now.year, now.month + 1, 1);
        final monthSessions = allSessions.where((s) {
          final startTimeRaw = s['startTime'];
          DateTime? startTime;
          if (startTimeRaw is String) {
            startTime = DateTime.tryParse(startTimeRaw);
          } else if (startTimeRaw is Timestamp) {
            startTime = startTimeRaw.toDate();
          }
          if (startTime == null) return false;
          return startTime.isAfter(monthStart) &&
              startTime.isBefore(monthEnd);
        }).toList();

        // 이번 주 세션 필터링
        final weekStartDt = _weekStart(now);
        final weekEndDt = _weekEnd(now);
        final weekSessions = allSessions.where((s) {
          final startTimeRaw = s['startTime'];
          DateTime? startTime;
          if (startTimeRaw is String) {
            startTime = DateTime.tryParse(startTimeRaw);
          } else if (startTimeRaw is Timestamp) {
            startTime = startTimeRaw.toDate();
          }
          if (startTime == null) return false;
          return startTime.isAfter(weekStartDt) &&
              startTime.isBefore(weekEndDt);
        }).toList();

        // 이번 달 총 거리 (km)
        final monthlyDistanceKm = monthSessions.fold<double>(
            0.0,
            (acc, s) =>
                acc + ((s['distanceKm'] as num?)?.toDouble() ?? 0.0));

        // 이번 주 총 거리 (km)
        final weeklyDistanceKm = weekSessions.fold<double>(
            0.0,
            (acc, s) =>
                acc + ((s['distanceKm'] as num?)?.toDouble() ?? 0.0));

        // 이번 주 러닝 횟수
        final weeklyCount = weekSessions.length.toDouble();

        // 각 목표의 currentValue를 자동 계산값으로 교체
        return filtered.map((goal) {
          double computedCurrent;
          switch (goal.type) {
            case GoalType.monthlyDistance:
              computedCurrent = monthlyDistanceKm;
            case GoalType.weeklyDistance:
              computedCurrent = weeklyDistanceKm;
            case GoalType.weeklyCount:
              computedCurrent = weeklyCount;
            case GoalType.streak:
              // streak은 UI에서 기존 currentValue 사용
              computedCurrent = goal.currentValue;
          }

          final isCompleted = computedCurrent >= goal.targetValue;

          // GoalModel로 재구성 (변경된 currentValue/isCompleted 반영)
          return GoalModel(
            id: goal.id,
            type: goal.type,
            targetValue: goal.targetValue,
            currentValue: computedCurrent,
            period: goal.period,
            isCompleted: isCompleted,
            createdAt: goal.createdAt,
          );
        }).toList();
      });
});

// ── 목표 추가 Provider ────────────────────────────────────────────────────
// userId, GoalType, 목표 수치를 받아 Firestore에 저장
// currentValue는 초기 0.0 — goalsProvider에서 실시간 계산
final addGoalProvider =
    Provider<Future<void> Function(String userId, GoalType type, double target)>(
  (ref) {
    return (userId, type, target) async {
      // 월간 목표: "2026-03", 주간 목표: "2026-W12"
      final period = type == GoalType.monthlyDistance
          ? _currentPeriod(isMonthly: true)
          : _currentPeriod(isMonthly: false);

      final goalDs = ref.read(goalFirestoreDataSourceProvider);
      final now = DateTime.now();

      // 초기 currentValue = 0, goalsProvider 스트림에서 자동 계산됨
      final model = GoalModel(
        id: '', // addGoal에서 Firestore auto-id 사용 (dummy)
        type: type,
        targetValue: target,
        currentValue: 0.0,
        period: period,
        isCompleted: false,
        createdAt: now,
      );

      await goalDs.addGoal(userId, model);
    };
  },
);
