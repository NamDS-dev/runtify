import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// GPS 신호 강도 단계 — 시작 전 배지 + 약함 시 경고 배너용.
enum GpsSignalLevel {
  good,    // accuracy ≤ 10m
  ok,      // accuracy ≤ 25m
  weak,    // accuracy > 25m
  unknown, // 권한 없음 / 서비스 꺼짐 / 아직 fix 못 받음
}

/// 정확도(미터)를 단계로 분류 — 단위 테스트 친화 형태.
GpsSignalLevel classifyAccuracy(double accuracyMeters) {
  if (accuracyMeters <= 10) return GpsSignalLevel.good;
  if (accuracyMeters <= 25) return GpsSignalLevel.ok;
  return GpsSignalLevel.weak;
}

/// 시작 화면에서 GPS 신호 강도를 실시간으로 보여주는 StreamProvider.
///
/// `running_page.dart`의 시작 전 화면에서만 watch 해 시작 후에는 자동 dispose
/// (autoDispose) — 시작 후엔 본 페이지의 `_positionSubscription`이 GPS를 담당.
final gpsSignalProvider = StreamProvider.autoDispose<GpsSignalLevel>((ref) async* {
  // 웹/테스트 환경에서는 항상 unknown
  if (kIsWeb) {
    yield GpsSignalLevel.unknown;
    return;
  }

  // 권한 체크 — 거부 상태에서 stream 띄우면 onError 발생
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      yield GpsSignalLevel.unknown;
      return;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      yield GpsSignalLevel.unknown;
      return;
    }
  } catch (_) {
    yield GpsSignalLevel.unknown;
    return;
  }

  // 첫 fix 받기 전엔 unknown
  yield GpsSignalLevel.unknown;

  GpsSignalLevel? lastLevel;
  await for (final position in Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    ),
  )) {
    final level = classifyAccuracy(position.accuracy);
    if (level != lastLevel) {
      lastLevel = level;
      yield level;
    }
  }
});
