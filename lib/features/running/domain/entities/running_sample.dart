import 'package:equatable/equatable.dart';

/// 러닝 중 일정 간격으로 캡처되는 샘플 (페이스/고도/심박수).
///
/// 결과 페이지 차트에 사용. 10초 간격 샘플링 → 10km/40분 러닝 ≈ 240개 샘플로 Firestore 부담 적음.
class RunningSample extends Equatable {
  /// 러닝 시작 시점부터의 경과 초.
  final int elapsedSeconds;
  /// 그 시점의 누적 평균 페이스(분/km). 0 이면 데이터 없음/거리 0.
  final double paceMinPerKm;
  /// 고도(m). GPS altitude 그대로. 0 일 수 있음.
  final double altitudeM;
  /// 심박수(bpm). 0 이면 BLE 연결 없음.
  final double heartRate;

  const RunningSample({
    required this.elapsedSeconds,
    required this.paceMinPerKm,
    required this.altitudeM,
    required this.heartRate,
  });

  Map<String, dynamic> toJson() => {
        'elapsedSeconds': elapsedSeconds,
        'paceMinPerKm': paceMinPerKm,
        'altitudeM': altitudeM,
        'heartRate': heartRate,
      };

  factory RunningSample.fromJson(Map<String, dynamic> j) => RunningSample(
        elapsedSeconds: (j['elapsedSeconds'] ?? 0) as int,
        paceMinPerKm: (j['paceMinPerKm'] ?? 0.0).toDouble(),
        altitudeM: (j['altitudeM'] ?? 0.0).toDouble(),
        heartRate: (j['heartRate'] ?? 0.0).toDouble(),
      );

  @override
  List<Object?> get props => [elapsedSeconds, paceMinPerKm, altitudeM, heartRate];
}
