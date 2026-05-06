import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/firebase_timeout.dart';
import '../../data/datasources/health_connect_datasource.dart';
import '../../data/datasources/running_firestore_datasource.dart';
import '../../data/datasources/running_mock_datasource.dart';
import '../../domain/entities/running_session_entity.dart';

// HealthConnect 데이터소스 (싱글톤으로 권한 상태 유지)
// 웹에서는 Health() 생성자가 Pigeon 채널을 초기화해 크래시 → 지연 생성으로 처리
final healthConnectDataSourceProvider = Provider<HealthConnectDataSource>((ref) {
  return HealthConnectDataSource(); // 내부에서 kIsWeb 시 Health() 생성 안 함
});

// 러닝 데이터소스 선택:
// - 웹 → 목업 데이터
// - Android (debug/release) → Firestore (실제 저장/조회)
final runningDataSourceProvider = Provider<RunningDataSource>((ref) {
  if (kIsWeb) return RunningMockDataSource();
  return RunningFirestoreDataSource(firestore: FirebaseFirestore.instance);
});

// Health Connect 권한 상태 관리
class HealthPermissionNotifier extends StateNotifier<AsyncValue<bool>> {
  final HealthConnectDataSource _dataSource;
  final bool _isDemoMode;

  HealthPermissionNotifier(this._dataSource, {bool isDemoMode = false})
      : _isDemoMode = isDemoMode,
        super(const AsyncValue.loading()) {
    if (isDemoMode) {
      state = const AsyncValue.data(true);
    } else {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final hasPerms = await _dataSource.hasPermissions();
    state = AsyncValue.data(hasPerms);
  }

  Future<void> requestPermission() async {
    if (_isDemoMode) return;
    state = const AsyncValue.loading();
    final granted = await _dataSource.requestPermissions();
    state = AsyncValue.data(granted);
  }
}

final healthPermissionProvider =
    StateNotifierProvider<HealthPermissionNotifier, AsyncValue<bool>>((ref) {
  return HealthPermissionNotifier(
    ref.read(healthConnectDataSourceProvider),
    isDemoMode: kIsWeb,
  );
});

// 최근 러닝 기록 목록 (userId별 조회)
final recentRunsProvider =
    FutureProvider.family<List<RunningSessionEntity>, String>(
  (ref, userId) async {
    final dataSource = ref.read(runningDataSourceProvider);
    return dataSource.getRecentSessions(userId);
  },
);

// 특정 월의 전체 러닝 세션 (캘린더 탭용)
// record 타입을 family 파라미터로 사용: (userId, year, month)
final monthlySessionsProvider = FutureProvider.family<List<RunningSessionEntity>,
    ({String userId, int year, int month})>(
  (ref, param) async {
    final dataSource = ref.read(runningDataSourceProvider);
    return dataSource.getSessionsByMonth(param.userId, param.year, param.month);
  },
);

// 이번 달 총 거리 계산
final monthlyDistanceProvider =
    Provider.family<double, List<RunningSessionEntity>>(
  (ref, sessions) {
    final now = DateTime.now();
    return sessions
        .where((s) =>
            s.startTime.year == now.year && s.startTime.month == now.month)
        .fold(0.0, (total, s) => total + s.distanceKm);
  },
);

// ── 지역 계층형 랭킹 ────────────────────────────────────────────────────

// 지역 랭킹 항목 모델
class RegionRankEntry {
  final String region;         // 지역 이름 (예: "강남구")
  final String? parentRegion;  // 상위 지역 (예: "서울특별시") — nullable
  final int totalPoints;       // 해당 지역 누적 포인트
  final int runnerCount;       // 해당 지역 러너 수

  RegionRankEntry({
    required this.region,
    this.parentRegion,
    required this.totalPoints,
    required this.runnerCount,
  });
}

// 지역 랭킹 Provider — level(gu/si/dong)과 month(YYYY-MM) 기준 조회
// 포인트 내림차순, 최대 30개 제한
final regionRankingProvider = FutureProvider.family<List<RegionRankEntry>,
    ({String level, String month})>(
  (ref, param) async {
    final snapshot = await withFirebaseTimeout(
      FirebaseFirestore.instance
          .collection('regionStats')
          .where('level', isEqualTo: param.level)
          .where('month', isEqualTo: param.month)
          .orderBy('totalPoints', descending: true)
          .limit(30)
          .get(),
      operation: 'regionRanking_${param.level}',
    );

    return snapshot.docs.map((doc) {
      final d = doc.data();
      return RegionRankEntry(
        region: d['region'] as String,
        parentRegion: d['parentRegion'] as String?,
        totalPoints: (d['totalPoints'] ?? 0) as int,
        runnerCount: (d['runnerCount'] ?? 0) as int,
      );
    }).toList();
  },
);

// 목표(Goals) 관련 Provider는 goal_provider.dart로 분리됨
// import '../providers/goal_provider.dart' 참조
