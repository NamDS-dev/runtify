import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:health/health.dart';
import '../../../../core/error/failures.dart';
import '../models/running_session_model.dart';
import 'running_mock_datasource.dart';

// Health Connect를 통해 갤럭시 워치 러닝 데이터를 가져오는 데이터소스
// 데이터 흐름: 갤럭시 워치 → 삼성 헬스 앱 → Health Connect → 이 클래스
// 웹에서는 Health() 생성 불가 (Pigeon 채널 미지원) → 메서드 호출 시 빈 값 반환
class HealthConnectDataSource implements RunningDataSource {
  // 웹에서는 Health 인스턴스를 생성하지 않음 (Pigeon 플랫폼 채널 미지원)
  Health? _healthInstance;
  Health get _health {
    _healthInstance ??= Health();
    return _healthInstance!;
  }

  // Runtify에서 필요한 Health Connect 데이터 타입 목록
  // (const 사용 불가 - HealthDataType이 런타임 값이기 때문에 final 사용)
  static final List<HealthDataType> _requiredTypes = [
    HealthDataType.WORKOUT,                  // 운동 세션 (러닝)
    HealthDataType.HEART_RATE,               // 심박수
    HealthDataType.DISTANCE_WALKING_RUNNING, // 거리
    HealthDataType.TOTAL_CALORIES_BURNED,    // 칼로리
    HealthDataType.STEPS,                    // 걸음수
  ];

  // 권한 요청 (앱 시작 시 또는 홈 화면에서 호출)
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false; // 웹 미지원
    try {
      final granted = await _health.requestAuthorization(_requiredTypes);
      return granted;
    } catch (e) {
      throw WearableFailure('Health Connect 권한 요청 실패: $e');
    }
  }

  // 권한이 이미 부여됐는지 확인
  Future<bool> hasPermissions() async {
    if (kIsWeb) return false; // 웹 미지원
    try {
      return await _health.hasPermissions(_requiredTypes) ?? false;
    } catch (e) {
      return false;
    }
  }

  // 최근 러닝 세션 목록 가져오기
  @override
  Future<List<RunningSessionModel>> getRecentSessions(String userId) async {
    if (kIsWeb) return []; // 웹 미지원
    final hasPerms = await hasPermissions();
    if (!hasPerms) {
      throw WearableFailure('Health Connect 권한이 없습니다');
    }

    try {
      final now = DateTime.now();
      // 최근 30일간의 워크아웃 데이터 조회
      final startTime = now.subtract(const Duration(days: 30));

      final workouts = await _health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: now,
        types: [HealthDataType.WORKOUT],
      );

      // WORKOUT 타입 중 러닝(workout_type == RUNNING)만 필터링
      final runningWorkouts = workouts.where((data) {
        if (data.value is WorkoutHealthValue) {
          final workout = data.value as WorkoutHealthValue;
          return workout.workoutActivityType ==
              HealthWorkoutActivityType.RUNNING;
        }
        return false;
      }).toList();

      // 각 러닝 세션에 대해 심박수 데이터를 추가로 조회해서 결합
      final sessions = <RunningSessionModel>[];
      for (final workout in runningWorkouts) {
        final session = await _buildSessionFromWorkout(workout, userId);
        sessions.add(session);
      }

      // 최신 순으로 정렬
      sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      return sessions;
    } catch (e) {
      if (e is WearableFailure) rethrow;
      throw WearableFailure('러닝 데이터 조회 실패: $e');
    }
  }

  // 워크아웃 데이터로 RunningSessionModel 조립
  Future<RunningSessionModel> _buildSessionFromWorkout(
    HealthDataPoint workoutData,
    String userId,
  ) async {
    final workout = workoutData.value as WorkoutHealthValue;
    final startTime = workoutData.dateFrom;
    final endTime = workoutData.dateTo;
    final durationSeconds = endTime.difference(startTime).inSeconds;

    // 해당 세션 시간대의 심박수 데이터 조회
    double avgHeartRate = 0;
    try {
      final hrData = await _health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: endTime,
        types: [HealthDataType.HEART_RATE],
      );
      if (hrData.isNotEmpty) {
        final hrValues = hrData
            .map((d) => (d.value as NumericHealthValue).numericValue.toDouble())
            .toList();
        avgHeartRate = hrValues.reduce((a, b) => a + b) / hrValues.length;
      }
    } catch (e) {
      // 심박수 조회 실패해도 세션은 저장
    }

    // 거리 (Health Connect는 미터 단위로 제공)
    final distanceMeters =
        (workout.totalDistance ?? 0).toDouble();
    final distanceKm = distanceMeters / 1000;

    // 평균 페이스 계산 (분/km)
    final avgPace = distanceKm > 0
        ? (durationSeconds / 60) / distanceKm
        : 0.0;

    // 포인트 계산 (1km당 10포인트)
    final points = (distanceKm * 10).round();

    return RunningSessionModel(
      id: '${userId}_${startTime.millisecondsSinceEpoch}',
      userId: userId,
      startTime: startTime,
      endTime: endTime,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      avgPaceMinPerKm: avgPace,
      avgHeartRate: avgHeartRate,
      calories: (workout.totalEnergyBurned ?? 0).toDouble(),
      expEarned: points,
      pointsEarned: points,
      region: '',
    );
  }

  // 세션 저장 (Health Connect에 직접 쓰기는 권한 필요 - 현재는 미구현)
  @override
  Future<RunningSessionModel> saveSession(RunningSessionModel session) async {
    // TODO: Health Connect 쓰기 권한 추가 후 구현
    return session;
  }

  // 특정 월의 세션 조회 (Health Connect는 미구현 - 빈 목록 반환)
  // 캘린더 탭은 Firestore 데이터를 사용하므로 Health Connect 쪽은 no-op
  @override
  Future<List<RunningSessionModel>> getSessionsByMonth(
      String userId, int year, int month) async {
    return [];
  }

  // 세션 삭제 (Health Connect는 삭제 불가 - no-op)
  @override
  Future<void> deleteSession(String sessionId) async {
    // Health Connect는 앱이 직접 삭제할 수 없음
  }
}
