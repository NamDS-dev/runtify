import 'package:equatable/equatable.dart';

/// 1km 자동 분할 랩 데이터.
///
/// `splitPaces`(SplitPace)는 km/페이스만 보유하는 레거시 구조.
/// `LapData`는 추가로 구간 소요 초 + 평균 심박수까지 포함해 결과 페이지 랩 테이블에 사용.
class LapData extends Equatable {
  final int km;                  // N번째 km (1, 2, 3, ...)
  final int splitSeconds;        // 이 랩(=1km) 동안의 소요 초
  final double pace;             // 분/km (splitSeconds / 60)
  final double avgHeartRate;     // 이 랩 동안의 평균 심박수 (없으면 0)

  const LapData({
    required this.km,
    required this.splitSeconds,
    required this.pace,
    this.avgHeartRate = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'km': km,
        'splitSeconds': splitSeconds,
        'pace': pace,
        'avgHeartRate': avgHeartRate,
      };

  factory LapData.fromJson(Map<String, dynamic> j) => LapData(
        km: (j['km'] ?? 0) as int,
        splitSeconds: (j['splitSeconds'] ?? 0) as int,
        pace: (j['pace'] ?? 0.0).toDouble(),
        avgHeartRate: (j['avgHeartRate'] ?? 0.0).toDouble(),
      );

  /// MM:SS 포맷 (시간 라벨용)
  String get formattedSplitTime {
    final m = splitSeconds ~/ 60;
    final s = splitSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// X'YY" 포맷 (페이스 라벨용)
  String get formattedPace {
    if (pace <= 0) return "--'--\"";
    final m = pace.floor();
    final s = ((pace - m) * 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

  @override
  List<Object?> get props => [km, splitSeconds, pace, avgHeartRate];
}
