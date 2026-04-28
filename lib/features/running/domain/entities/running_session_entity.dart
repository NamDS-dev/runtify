import 'package:equatable/equatable.dart';

// 구간 페이스 데이터 (예: 1km마다 기록)
class SplitPace {
  final int km;           // 몇 번째 km (1, 2, 3...)
  final double pace;      // 해당 km 페이스 (분/km)

  const SplitPace({required this.km, required this.pace});
}

// GPS 좌표 포인트
class LatLngPoint {
  final double lat;
  final double lng;

  const LatLngPoint({required this.lat, required this.lng});
}

// 하나의 러닝 세션 데이터 객체
class RunningSessionEntity extends Equatable {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceKm;       // 거리 (km)
  final int durationSeconds;     // 소요 시간 (초)
  final double avgPaceMinPerKm;  // 평균 페이스 (분/km)
  final double avgHeartRate;     // 평균 심박수 (bpm)
  final double calories;         // 소모 칼로리 (kcal)
  final int expEarned;           // 이 세션으로 얻은 경험치 (레벨업용)
  final int pointsEarned;        // 이 세션으로 얻은 포인트 (재화)
  final String region;           // 러닝 지역 (역지오코딩 결과, 하위 호환용)
  final List<LatLngPoint> routePoints;  // GPS 경로 포인트 목록
  final List<SplitPace> splitPaces;    // 구간별 페이스 (km마다 기록)

  // 하위 호환 지역 필드 (레거시 — geoRegion* 필드로 대체)
  final String? regionDong;   // 동 단위 (예: "역삼동")
  final String? regionGu;     // 구/군 단위 (예: "강남구")
  final String? regionSi;     // 시·도 단위 (예: "서울특별시")

  // 실제 뛴 위치 (GPS 역지오코딩 결과)
  final String? geoRegionSi;   // 뛴 위치 시·도
  final String? geoRegionGu;   // 뛴 위치 구·군
  final String? geoRegionDong; // 뛴 위치 동

  // 랭킹 기여 지역 (홈 지역 우선, 없으면 geoRegion, 컨펌 후 설정 가능)
  final String? rankingRegionSi;   // 랭킹 기여 시·도
  final String? rankingRegionGu;   // 랭킹 기여 구·군
  final String? rankingRegionDong; // 랭킹 기여 동

  // 이번 세션에서 새로 획득한 배지 ID 목록 (Firestore 미저장, 결과 화면 팝업용)
  final List<String> newBadgeIds;

  // 이번 세션에서 갱신된 PB 거리 키 목록 ('1k'/'5k'/'10k'/'half'/'full')
  // Firestore 미저장, 결과 화면 🏆 배너 표시용
  final List<String> newPersonalRecords;

  // 사용자가 부여한 제목·메모 (러닝 종료 후 또는 기록 상세에서 편집 가능)
  final String? title;
  final String? memo;

  const RunningSessionEntity({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.distanceKm = 0.0,
    this.durationSeconds = 0,
    this.avgPaceMinPerKm = 0.0,
    this.avgHeartRate = 0.0,
    this.calories = 0.0,
    this.expEarned = 0,
    this.pointsEarned = 0,
    this.region = '',
    this.routePoints = const [],
    this.splitPaces = const [],
    this.regionDong,
    this.regionGu,
    this.regionSi,
    this.geoRegionSi,
    this.geoRegionGu,
    this.geoRegionDong,
    this.rankingRegionSi,
    this.rankingRegionGu,
    this.rankingRegionDong,
    this.newBadgeIds = const [],
    this.newPersonalRecords = const [],
    this.title,
    this.memo,
  });

  bool get isCompleted => endTime != null;

  @override
  List<Object?> get props => [
        id,
        userId,
        startTime,
        distanceKm,
        regionDong,
        regionGu,
        regionSi,
        geoRegionSi,
        geoRegionGu,
        geoRegionDong,
        rankingRegionSi,
        rankingRegionGu,
        rankingRegionDong,
      ];
}
