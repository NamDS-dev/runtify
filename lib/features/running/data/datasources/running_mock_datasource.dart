import '../models/running_session_model.dart';

// RunningDataSource 인터페이스
abstract class RunningDataSource {
  Future<List<RunningSessionModel>> getRecentSessions(String userId);
  // 특정 연/월의 전체 세션 조회 (캘린더 탭에서 사용)
  Future<List<RunningSessionModel>> getSessionsByMonth(
      String userId, int year, int month);
  Future<RunningSessionModel> saveSession(RunningSessionModel session);
  Future<void> deleteSession(String sessionId);
}

// 목업 데이터소스 - Health Connect 연동 전 또는 웹/데모 모드에서 사용
class RunningMockDataSource implements RunningDataSource {
  final List<RunningSessionModel> _mockData = [
    RunningSessionModel(
      id: 'mock_1',
      userId: 'demo_user_001',
      startTime: DateTime.now().subtract(const Duration(days: 1)),
      endTime: DateTime.now().subtract(const Duration(days: 1, hours: -1)),
      distanceKm: 5.3,
      durationSeconds: 1800,
      avgPaceMinPerKm: 5.66,
      avgHeartRate: 152.0,
      calories: 312.0,
      pointsEarned: 53,
      region: '서울시 강남구',
    ),
    RunningSessionModel(
      id: 'mock_2',
      userId: 'demo_user_001',
      startTime: DateTime.now().subtract(const Duration(days: 3)),
      endTime: DateTime.now().subtract(const Duration(days: 3, hours: -1)),
      distanceKm: 8.1,
      durationSeconds: 2880,
      avgPaceMinPerKm: 5.93,
      avgHeartRate: 148.0,
      calories: 476.0,
      pointsEarned: 81,
      region: '서울시 강남구',
    ),
    RunningSessionModel(
      id: 'mock_3',
      userId: 'demo_user_001',
      startTime: DateTime.now().subtract(const Duration(days: 5)),
      endTime: DateTime.now().subtract(const Duration(days: 5, hours: -1)),
      distanceKm: 3.7,
      durationSeconds: 1200,
      avgPaceMinPerKm: 5.40,
      avgHeartRate: 145.0,
      calories: 218.0,
      pointsEarned: 37,
      region: '서울시 강남구',
    ),
  ];

  @override
  Future<List<RunningSessionModel>> getRecentSessions(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockData.where((s) => s.userId == userId).toList();
  }

  @override
  Future<List<RunningSessionModel>> getSessionsByMonth(
      String userId, int year, int month) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockData
        .where((s) =>
            s.userId == userId &&
            s.startTime.year == year &&
            s.startTime.month == month)
        .toList();
  }

  @override
  Future<RunningSessionModel> saveSession(RunningSessionModel session) async {
    _mockData.add(session);
    return session;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _mockData.removeWhere((s) => s.id == sessionId);
  }
}
