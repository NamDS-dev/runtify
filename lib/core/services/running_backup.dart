import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 진행 중 러닝의 SharedPreferences 백업.
///
/// 30초마다 [save] 호출 → 앱 강제 종료/크래시 후 재실행 시 [load]로 복구 가능.
/// 정상 종료 흐름에서는 [clear] 호출로 키 삭제.
class RunningBackupSnapshot {
  final DateTime startTime;
  final double distanceKm;
  final int durationSeconds;
  final double avgHeartRate;
  // [[lat, lng], ...] — JSON 직렬화 친화 형태
  final List<List<double>> routePoints;
  // [[km, pace], ...]
  final List<List<double>> splitPaces;
  final double? lastLat;
  final double? lastLng;
  final double? firstLat;
  final double? firstLng;

  const RunningBackupSnapshot({
    required this.startTime,
    required this.distanceKm,
    required this.durationSeconds,
    required this.avgHeartRate,
    required this.routePoints,
    required this.splitPaces,
    this.lastLat,
    this.lastLng,
    this.firstLat,
    this.firstLng,
  });

  Map<String, dynamic> toJson() => {
        'startTime': startTime.toIso8601String(),
        'distanceKm': distanceKm,
        'durationSeconds': durationSeconds,
        'avgHeartRate': avgHeartRate,
        'routePoints': routePoints,
        'splitPaces': splitPaces,
        'lastLat': lastLat,
        'lastLng': lastLng,
        'firstLat': firstLat,
        'firstLng': firstLng,
      };

  static RunningBackupSnapshot? fromJson(Map<String, dynamic> j) {
    try {
      final routes = ((j['routePoints'] as List?) ?? <dynamic>[])
          .map((p) => (p as List)
              .map((e) => (e as num).toDouble())
              .toList())
          .toList();
      final splits = ((j['splitPaces'] as List?) ?? <dynamic>[])
          .map((p) => (p as List)
              .map((e) => (e as num).toDouble())
              .toList())
          .toList();
      return RunningBackupSnapshot(
        startTime: DateTime.parse(j['startTime'] as String),
        distanceKm: (j['distanceKm'] as num).toDouble(),
        durationSeconds: (j['durationSeconds'] as num).toInt(),
        avgHeartRate: (j['avgHeartRate'] as num? ?? 0).toDouble(),
        routePoints: routes,
        splitPaces: splits,
        lastLat: (j['lastLat'] as num?)?.toDouble(),
        lastLng: (j['lastLng'] as num?)?.toDouble(),
        firstLat: (j['firstLat'] as num?)?.toDouble(),
        firstLng: (j['firstLng'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  /// 복구 가치가 있는 백업인지 — 너무 짧으면 노이즈로 간주.
  bool get isRecoverable => distanceKm >= 0.1 && durationSeconds >= 60;
}

class RunningBackup {
  static const String storageKey = 'running_in_progress_backup';

  /// 진행 중 러닝 스냅샷을 저장.
  /// 직렬화 실패 시 조용히 무시 — 사용자 흐름 차단 금지.
  Future<void> save(RunningBackupSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(snapshot.toJson()));
    } catch (_) {
      // 저장 실패는 러닝 자체를 막아선 안 됨
    }
  }

  /// 저장된 스냅샷 로드. 손상된 JSON은 null 반환.
  Future<RunningBackupSnapshot?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null) return null;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return RunningBackupSnapshot.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  /// 정상 종료/사용자 취소 시 키 삭제.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {
      // 무시
    }
  }
}
