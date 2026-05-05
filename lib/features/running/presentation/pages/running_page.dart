import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../core/providers/gps_signal_provider.dart';
import '../../../../core/services/running_backup.dart';
import '../../../../core/services/running_voice_announcer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/heart_rate_ble_datasource.dart';
import '../../data/models/running_session_model.dart';
import '../../data/services/running_notification_service.dart';
import '../../domain/entities/lap_data.dart';
import '../../domain/entities/running_sample.dart';
import '../../domain/entities/running_session_entity.dart';
import '../providers/running_provider.dart';
import '../widgets/lock_overlay.dart';

// 러닝 트래킹 화면 (지도 상단 50% + 스탯 패널 하단)
class RunningPage extends ConsumerStatefulWidget {
  const RunningPage({super.key});

  @override
  ConsumerState<RunningPage> createState() => _RunningPageState();
}

class _RunningPageState extends ConsumerState<RunningPage>
    with WidgetsBindingObserver {
  // 타이머 / 상태
  Timer? _timer;
  bool _isRunning = false;
  bool _isSaving = false;
  late DateTime _startTime;
  int _elapsedSeconds = 0;
  String? _gpsError;

  // GPS 경로
  StreamSubscription<Position>? _positionSubscription;
  double _distanceKm = 0.0;
  Position? _lastPosition;
  Position? _firstPosition; // 시작 지점 위치 (시작 구 판별용)
  final List<ll.LatLng> _routePoints = []; // 지도 폴리라인용
  final MapController _mapController = MapController();

  // 구간 페이스 (km마다 기록)
  final List<SplitPace> _splitPaces = [];
  // 랩 데이터 (1km 단위, 시간/페이스/평균 심박)
  final List<LapData> _laps = [];
  // 현재 진행 중 랩의 심박수 readings (랩 마감 시 평균 계산 후 비움)
  final List<int> _hrReadingsCurrentLap = [];
  // 10초 단위 샘플 (페이스/고도/심박) — 결과 페이지 차트용
  final List<RunningSample> _samples = [];
  Timer? _sampleTimer;

  // 1km 통과 시 음성 안내 (Profile 토글 ON일 때만)
  final RunningVoiceAnnouncer _voiceAnnouncer = RunningVoiceAnnouncer();
  double _lastSplitDistanceKm = 0.0; // 마지막 구간 시작 시점 거리
  int _lastSplitSeconds = 0;         // 마지막 구간 시작 시점 시간

  // BLE 심박수
  final _hrDataSource = HeartRateBleDataSource();
  final _notificationService = RunningNotificationService();
  StreamSubscription<int>? _hrSub;
  StreamSubscription<BleHrStatus>? _hrStatusSub;
  int _currentHr = 0;
  BleHrStatus _bleStatus = BleHrStatus.disconnected;

  // GPS stream 자동 재구독 카운터 — onError 시 max 3회까지 재시도
  int _gpsRestartAttempts = 0;
  static const int _gpsMaxRestartAttempts = 3;
  final List<int> _hrReadings = []; // 평균 심박수 계산용

  // 진행 중 러닝 백업 (앱 강제 종료/크래시 복구) — 30초 주기
  final RunningBackup _backup = RunningBackup();
  Timer? _backupTimer;

  // 잠금 화면 — 활성 시 종료 버튼/뒤로가기 차단, 위로 길게 스와이프(2초+)로만 해제
  bool _isLocked = false;

  // GPS 권한 확인 및 요청
  Future<bool> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _gpsError = 'GPS가 꺼져 있습니다. 설정에서 위치 서비스를 활성화해주세요.');
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _gpsError = '위치 권한이 거부되었습니다.');
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _gpsError = '위치 권한이 영구 거부되었습니다. 앱 설정에서 허용해주세요.');
      return false;
    }
    return true;
  }

  Future<void> _startRun() async {
    setState(() => _gpsError = null);
    final hasPermission = await _requestLocationPermission();
    if (!hasPermission) return;

    // GPS 신호가 weak 일 때 경고만 — 시작은 허용 (사용자가 인지하고 시작 결정)
    final signal = ref.read(gpsSignalProvider).valueOrNull;
    if (signal == GpsSignalLevel.weak && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ctx.colors.surface,
          title: Text('GPS 신호가 약해요',
              style: TextStyle(color: ctx.colors.textPrimary)),
          content: Text(
            '거리 측정이 부정확할 수 있어요. 야외 개방된 곳에서 시작하면 더 정확한 기록이 가능합니다.',
            style: TextStyle(color: ctx.colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('취소',
                  style: TextStyle(color: ctx.colors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('그래도 시작',
                  style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    // 알림 권한을 GPS stream 시작 전에 먼저 await — Android 13+에서 알림 권한 없으면
    // ForegroundNotificationConfig가 foreground service 시작에 실패해 stream이
    // 즉시 onError로 죽는 이슈를 방지. 거부되면 foreground 알림 없이 진행.
    bool notificationGranted = false;
    try {
      notificationGranted =
          await _notificationService.requestPermission().timeout(
                const Duration(seconds: 3),
                onTimeout: () => false,
              );
    } catch (_) {
      notificationGranted = false;
    }

    _startTime = DateTime.now();
    _lastPosition = null;
    _firstPosition = null;
    _distanceKm = 0.0;
    _elapsedSeconds = 0;
    _hrReadings.clear();
    _routePoints.clear();
    _splitPaces.clear();
    _laps.clear();
    _hrReadingsCurrentLap.clear();
    _samples.clear();
    _lastSplitDistanceKm = 0.0;
    _lastSplitSeconds = 0;
    _gpsRestartAttempts = 0;
    setState(() => _isRunning = true);

    _subscribePositionStream(notificationGranted: notificationGranted);

    // 경과 시간 타이머 먼저 등록 — 알림/BLE 권한 요청이 실패/hang해도 타이머는 반드시 동작
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds = DateTime.now().difference(_startTime).inSeconds;
      });
      // 워치/알림에 실시간 데이터 전송 — 실패해도 타이머는 계속 돌아야 함
      try {
        _notificationService.update(
          distanceKm: _distanceKm,
          elapsedSeconds: _elapsedSeconds,
          pace: _paceString,
          heartRate: _currentHr,
        );
      } catch (_) {
        // 알림 서비스 이슈(권한/플랫폼 미지원)는 무시
      }
    });

    // 30초마다 진행 상태 백업 — 앱 강제 종료/크래시 복구용
    _backupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isRunning) return;
      _backup.save(_currentBackupSnapshot());
    });

    // 10초마다 페이스/고도/심박 샘플링 — 결과 페이지 차트용
    _sampleTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isRunning) return;
      _samples.add(RunningSample(
        elapsedSeconds: _elapsedSeconds,
        paceMinPerKm: _currentPace,
        altitudeM: _lastPosition?.altitude ?? 0,
        heartRate: _currentHr.toDouble(),
      ));
    });

    // BLE 심박수 스캔 시작 — 실기기에서 권한/지원 이슈로 실패해도 러닝은 계속 진행
    _hrStatusSub = _hrDataSource.statusStream.listen((status) {
      if (mounted) setState(() => _bleStatus = status);
    });
    _hrSub = _hrDataSource.heartRateStream.listen((hr) {
      if (mounted) {
        setState(() => _currentHr = hr);
        _hrReadings.add(hr);
        _hrReadingsCurrentLap.add(hr);
      }
    });
    try {
      await _hrDataSource.startScan();
    } catch (_) {
      // BLE 미지원/권한 거부 — 심박수 없이 러닝 계속 진행
    }
  }

  // GPS stream 구독 — onError 시 _gpsMaxRestartAttempts 까지 backoff로 자동 재구독.
  // 알림 권한이 거부됐으면 foreground notification config 생략 (foreground service 시도 안 함).
  void _subscribePositionStream({required bool notificationGranted}) {
    final LocationSettings locationSettings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 2,
            foregroundNotificationConfig: notificationGranted
                ? const ForegroundNotificationConfig(
                    notificationTitle: 'Runtify 러닝 중',
                    notificationText: '러닝 기록이 진행되고 있습니다.',
                    enableWakeLock: true,
                  )
                : null,
          )
        : Platform.isIOS
            ? AppleSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 2,
                activityType: ActivityType.fitness,
                pauseLocationUpdatesAutomatically: false,
                allowBackgroundLocationUpdates: true,
                showBackgroundLocationIndicator: true,
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 2,
              );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        // 정상 이벤트 수신 — restart 카운터 리셋 + 에러 메시지 클리어
        if (_gpsRestartAttempts > 0 || _gpsError != null) {
          _gpsRestartAttempts = 0;
          if (_gpsError != null) setState(() => _gpsError = null);
        }

        // GPS 정확도 필터 — 초기 10초는 GPS lock 대기, 완화된 기준 50m 적용
        // (도심/건물 사이에서 초기 accuracy 25~40m 정상)
        final elapsedSinceStart = DateTime.now().difference(_startTime).inSeconds;
        if (elapsedSinceStart > 10 && position.accuracy > 50) return;

        // 속도 기반 노이즈 필터: 정지 상태(0.3m/s 미만)에서 거리 누적 방지
        // 0.3m/s ≈ 1.08km/h — 걷기보다 느리면 GPS 떨림으로 판단
        final isStationary = position.speed >= 0 && position.speed < 0.3;

        final point = ll.LatLng(position.latitude, position.longitude);

        // 첫 번째 유효 GPS 위치 저장 (시작 구 판별용)
        _firstPosition ??= position;

        if (_lastPosition != null && !isStationary) {
          final meters = Geolocator.distanceBetween(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
            position.latitude,
            position.longitude,
          );

          // 이상치 필터: 한 번에 100m 이상 점프하면 GPS 오류로 간주
          if (meters > 100) return;

          _distanceKm += meters / 1000;

          // km 단위 구간 페이스 기록 (1km, 2km, 3km...)
          final currentKm = _distanceKm.floor();
          final lastKm = _lastSplitDistanceKm.floor();
          if (currentKm > lastKm && currentKm > 0) {
            // 해당 구간(1km)을 달린 시간 계산
            final splitSeconds = _elapsedSeconds - _lastSplitSeconds;
            final splitPace = splitSeconds > 0 ? splitSeconds / 60.0 : 0.0;
            _splitPaces.add(SplitPace(km: currentKm, pace: splitPace));
            // 랩 데이터 — 평균 심박수까지 포함 (이번 랩 동안 들어온 readings)
            final lapHr = _hrReadingsCurrentLap.isNotEmpty
                ? _hrReadingsCurrentLap.reduce((a, b) => a + b) /
                    _hrReadingsCurrentLap.length
                : 0.0;
            _laps.add(LapData(
              km: currentKm,
              splitSeconds: splitSeconds,
              pace: splitPace,
              avgHeartRate: lapHr,
            ));
            // 음성 안내 — 비활성화돼 있으면 announcer 내부에서 즉시 반환
            _voiceAnnouncer.announceKm(
              km: currentKm,
              paceMinPerKm: splitPace,
              avgHeartRate: lapHr,
            );
            _hrReadingsCurrentLap.clear();
            _lastSplitDistanceKm = _distanceKm;
            _lastSplitSeconds = _elapsedSeconds;
          }
        }

        // 경로 포인트 누적 + 지도 자동 이동 (정지 상태에서도 위치 표시는 업데이트)
        setState(() {
          if (!isStationary) _routePoints.add(point);
          _lastPosition = position;
        });

        // 현재 위치로 지도 카메라 이동 — 백그라운드 복귀 시점 등 맵이 detach된 상태면 조용히 스킵
        if (_isRunning && mounted) {
          try {
            _mapController.move(point, _mapController.camera.zoom);
          } catch (_) {
            // MapController가 아직 attach되지 않았거나 dispose된 경우 무시
          }
        }
      },
      onError: (_) {
        if (!_isRunning || !mounted) return;
        if (_gpsRestartAttempts < _gpsMaxRestartAttempts) {
          _gpsRestartAttempts++;
          // 재구독 시도 — 1초/2초/4초 backoff
          final delay = Duration(seconds: 1 << (_gpsRestartAttempts - 1));
          setState(() => _gpsError =
              'GPS 신호 재연결 중... ($_gpsRestartAttempts/$_gpsMaxRestartAttempts)');
          _positionSubscription?.cancel();
          _positionSubscription = null;
          Future.delayed(delay, () {
            if (!_isRunning || !mounted) return;
            _subscribePositionStream(notificationGranted: notificationGranted);
          });
        } else {
          // 모든 재시도 실패 — 사용자에게 안내, 거리 누적 중단
          setState(() => _gpsError = 'GPS 신호를 받을 수 없습니다. 야외에서 시도해주세요.');
        }
      },
    );
  }

  // 현재 진행 상태를 백업 스냅샷으로 변환
  RunningBackupSnapshot _currentBackupSnapshot() {
    final avgHr = _hrReadings.isNotEmpty
        ? _hrReadings.reduce((a, b) => a + b) / _hrReadings.length
        : 0.0;
    return RunningBackupSnapshot(
      startTime: _startTime,
      distanceKm: _distanceKm,
      durationSeconds: _elapsedSeconds,
      avgHeartRate: avgHr,
      routePoints: _routePoints
          .map((p) => [p.latitude, p.longitude])
          .toList(),
      splitPaces: _splitPaces
          .map((s) => [s.km.toDouble(), s.pace])
          .toList(),
      laps: _laps
          .map((l) => [
                l.km.toDouble(),
                l.splitSeconds.toDouble(),
                l.pace,
                l.avgHeartRate,
              ])
          .toList(),
      lastLat: _lastPosition?.latitude,
      lastLng: _lastPosition?.longitude,
      firstLat: _firstPosition?.latitude,
      firstLng: _firstPosition?.longitude,
    );
  }

  Future<void> _stopRun() async {
    _timer?.cancel();
    _backupTimer?.cancel();
    _backupTimer = null;
    _sampleTimer?.cancel();
    _sampleTimer = null;
    // 정상 종료 — 백업 키 삭제 (저장 성공/실패와 무관, 러닝은 끝남)
    await _backup.clear();
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _hrDataSource.stop();
    await _hrStatusSub?.cancel();
    await _hrSub?.cancel();
    await _notificationService.cancel();

    setState(() {
      _isRunning = false;
      _isSaving = true;
    });

    final endTime = DateTime.now();
    final user = ref.read(authProvider).valueOrNull;
    RunningSessionModel? savedSession;

    if (user != null && _distanceKm > 0) {
      try {
        final earned = (_distanceKm * 10).round();
        final avgHr = _hrReadings.isNotEmpty
            ? _hrReadings.reduce((a, b) => a + b) / _hrReadings.length
            : 0.0;

        // 역지오코딩: 종료 위치 → 행정구역 3단계 (geoRegion — 실제 뛴 위치)
        String geoSi = '', geoGu = '', geoDong = '';
        if (_lastPosition != null) {
          final geo = await _reverseGeocode(
            _lastPosition!.latitude,
            _lastPosition!.longitude,
          );
          geoSi = geo.si;
          geoGu = geo.gu;
          geoDong = geo.dong;
        }

        // 역지오코딩: 시작 위치 → 시작 구 (startGu, 지역 컨펌 판별용)
        String startGu = '';
        if (_firstPosition != null) {
          final startGeo = await _reverseGeocode(
            _firstPosition!.latitude,
            _firstPosition!.longitude,
          );
          startGu = startGeo.gu;
        }

        // 기존 region 필드는 "시 구" 조합 문자열로 유지 (하위 호환)
        final region = [
          if (geoSi.isNotEmpty) geoSi,
          if (geoGu.isNotEmpty) geoGu,
        ].join(' ');

        // ── rankingRegion 결정 ──────────────────────────────────────
        // 홈 지역 설정 O → 항상 홈 지역 사용
        // 홈 지역 X + 시작=종료 구 → 뛴 위치 자동
        // 홈 지역 X + 시작≠종료 구 → 컨펌 UI (결과 화면에서 사용자 선택)
        final homeGu = user.homeRegionGu ?? '';
        final homeSi = user.homeRegionSi ?? '';
        final homeDong = user.homeRegionDong ?? '';
        final hasHomeRegion = homeGu.isNotEmpty;

        String rankingSi, rankingGu, rankingDong;
        bool needRegionConfirm = false;

        if (hasHomeRegion) {
          // 홈 지역 우선
          rankingSi = homeSi;
          rankingGu = homeGu;
          rankingDong = homeDong;
        } else if (startGu.isEmpty || startGu == geoGu) {
          // 홈 지역 없음 + 시작·종료 구 동일 → 자동 설정
          rankingSi = geoSi;
          rankingGu = geoGu;
          rankingDong = geoDong;
        } else {
          // 홈 지역 없음 + 시작≠종료 구 → 컨펌 필요 (일단 종료 위치로 임시 설정)
          rankingSi = geoSi;
          rankingGu = geoGu;
          rankingDong = geoDong;
          needRegionConfirm = true;
        }

        // 경로 포인트를 Entity 형식으로 변환
        final entityRoutePoints = _routePoints
            .map((p) => LatLngPoint(lat: p.latitude, lng: p.longitude))
            .toList();

        savedSession = RunningSessionModel(
          id: '${user.id}_${_startTime.millisecondsSinceEpoch}',
          userId: user.id,
          startTime: _startTime,
          endTime: endTime,
          distanceKm: _distanceKm,
          durationSeconds: _elapsedSeconds,
          avgPaceMinPerKm: _currentPace,
          avgHeartRate: avgHr,
          calories: _distanceKm * 60,
          expEarned: earned,
          pointsEarned: earned,
          region: region,
          // 하위 호환 필드 (geoRegion과 동일하게 유지)
          regionSi: geoSi.isNotEmpty ? geoSi : null,
          regionGu: geoGu.isNotEmpty ? geoGu : null,
          regionDong: geoDong.isNotEmpty ? geoDong : null,
          // 실제 뛴 위치
          geoRegionSi: geoSi.isNotEmpty ? geoSi : null,
          geoRegionGu: geoGu.isNotEmpty ? geoGu : null,
          geoRegionDong: geoDong.isNotEmpty ? geoDong : null,
          // 랭킹 기여 지역 (컨펌 필요 시 결과 화면에서 업데이트 가능)
          rankingRegionSi: rankingSi.isNotEmpty ? rankingSi : null,
          rankingRegionGu: rankingGu.isNotEmpty ? rankingGu : null,
          rankingRegionDong: rankingDong.isNotEmpty ? rankingDong : null,
          routePoints: entityRoutePoints,
          splitPaces: _splitPaces,
          laps: _laps,
          samples: _samples,
        );

        // 컨펌이 필요하지 않은 경우에만 즉시 저장
        // 컨펌 필요 시 결과 화면에서 사용자가 선택 후 저장
        if (!needRegionConfirm) {
          final dataSource = ref.read(runningDataSourceProvider);
          await dataSource.saveSession(savedSession);
          ref.invalidate(recentRunsProvider(user.id));
          await ref.read(authProvider.notifier).refreshUser();
        }

        // 컨펌 필요 시 extra에 추가 정보 전달
        if (mounted) {
          setState(() => _isSaving = false);
          if (needRegionConfirm) {
            context.go('/running/result', extra: {
              'session': savedSession,
              'needRegionConfirm': true,
              'startGu': startGu,
              'endGu': geoGu,
            });
          } else {
            context.go('/running/result', extra: {
              'session': savedSession,
              'needRegionConfirm': false,
              'startGu': startGu,
              'endGu': geoGu,
            });
          }
          return;
        }
      } catch (_) {}
    }

    setState(() => _isSaving = false);

    // 결과 페이지로 이동 (세션 없음 — 저장 실패 또는 거리 0)
    if (mounted) {
      context.go('/running/result', extra: {
        'session': null,
        'needRegionConfirm': false,
        'startGu': '',
        'endGu': '',
      });
    }
  }

  // 역지오코딩: GPS 좌표 → 한국 행정구역 3단계 분리
  // administrativeArea = 시·도 (서울특별시), locality = 구/군 (강남구), subLocality = 동 (역삼동)
  Future<({String si, String gu, String dong})> _reverseGeocode(
      double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return (si: '', gu: '', dong: '');
      final p = placemarks.first;
      return (
        si: p.administrativeArea ?? '',
        gu: p.locality ?? '',
        dong: p.subLocality ?? '',
      );
    } catch (_) {
      return (si: '', gu: '', dong: '');
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _currentPace =>
      _distanceKm > 0 ? (_elapsedSeconds / 60) / _distanceKm : 0.0;

  String get _paceString {
    if (_currentPace <= 0) return "--'--\"";
    final min = _currentPace.floor();
    final sec = ((_currentPace - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드/포그라운드 전환 시 위젯 안전 유지.
    // iOS Scene 기반 앱에서 복귀 시 MapController/stream 접근이 크래시로 이어지지 않도록 처리.
    if (!_isRunning) return;
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _backupTimer?.cancel();
    _sampleTimer?.cancel();
    _positionSubscription?.cancel();
    _mapController.dispose();
    _hrDataSource.dispose();
    _hrSub?.cancel();
    _hrStatusSub?.cancel();
    _voiceAnnouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 저장 중 로딩 화면
    if (_isSaving) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.primary),
              const SizedBox(height: 16),
              Text('기록 저장 중...',
                  style: TextStyle(color: context.colors.textSecondary)),
            ],
          ),
        ),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // ─── 상단 50%: 지도 ───────────────────────────────────────
              SizedBox(
                height: screenHeight * 0.5,
                child: _buildMap(),
              ),

              // ─── 하단 50%: 스탯 패널 ──────────────────────────────────
              Expanded(child: _buildStatsPanel()),
            ],
          ),

          // 뒤로가기 버튼 (지도 위에 오버레이) — 잠금 중 숨김
          if (!_isLocked)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _onBackPressed,
                  ),
                ),
              ),
            ),

          // 자물쇠 토글 버튼 — 러닝 중 우측 상단 (잠금 중에는 오버레이가 가림)
          if (_isRunning && !_isLocked)
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.lock_open, color: Colors.white),
                      tooltip: '화면 잠금',
                      onPressed: () => setState(() => _isLocked = true),
                    ),
                  ),
                ),
              ),
            ),

          // GPS 오류 배너 (지도 위에 오버레이)
          if (_gpsError != null && !_isLocked)
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _gpsError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),

          // 시작 전 GPS 신호 강도 배지 — 러닝 시작 시 자동 dispose (autoDispose)
          if (!_isRunning)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: const _GpsSignalBadge(),
            ),

          // 잠금 오버레이 — 활성 시 모든 하위 터치 차단, 위로 길게 스와이프(2초+)로만 해제
          if (_isLocked)
            Positioned.fill(
              child: LockOverlay(
                onUnlock: () => setState(() => _isLocked = false),
              ),
            ),
        ],
      ),
    );
  }

  // 지도 위젯 (CartoDB Dark + 경로 폴리라인 + 현재 위치 마커)
  Widget _buildMap() {
    final currentPos = _routePoints.isNotEmpty ? _routePoints.last : null;
    final center = currentPos ?? const ll.LatLng(37.5665, 126.9780); // 기본: 서울

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        // CartoDB Dark Matter 타일 (다크 테마에 어울리는 OSM)
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.runtify.app',
        ),

        // GPS 경로 폴리라인 (주황색)
        if (_routePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                color: AppTheme.primary,
                strokeWidth: 4,
              ),
            ],
          ),

        // 현재 위치 마커 (파란 원)
        if (currentPos != null)
          MarkerLayer(
            markers: [
              Marker(
                point: currentPos,
                width: 20,
                height: 20,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

        // 시작 지점 마커 (초록 원)
        if (_routePoints.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: _routePoints.first,
                width: 16,
                height: 16,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  // 스탯 패널 (하단 절반)
  Widget _buildStatsPanel() {
    return Container(
      color: context.colors.background,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          // ─── 거리 + 시간 (2열) ────────────────────────────────
          Row(
            children: [
              // 거리 (크게)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _distanceKm.toStringAsFixed(2),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'km',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // 시간
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(_elapsedSeconds),
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '시간',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─── 페이스 + 심박수 + 케이던스 (3열) ─────────────────
          Row(
            children: [
              // 페이스
              Expanded(
                child: _StatTile(
                  label: '페이스/km',
                  value: _paceString,
                  color: AppTheme.secondary,
                ),
              ),
              const SizedBox(width: 10),
              // 심박수
              Expanded(
                child: _HrStatTile(hr: _currentHr, status: _bleStatus),
              ),
              const SizedBox(width: 10),
              // 케이던스 (UI 플레이스홀더 - 추후 가속도계 연동)
              const Expanded(
                child: _StatTile(
                  label: '케이던스',
                  value: '-- spm',
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const Spacer(),

          // ─── 시작/정지 버튼 ─────────────────────────────────────
          GestureDetector(
            onTap: _isRunning ? _stopRun : _startRun,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRunning ? Colors.red : AppTheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: (_isRunning ? Colors.red : AppTheme.primary)
                        .withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                _isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isRunning ? '탭하여 종료' : '탭하여 시작',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // 뒤로가기: 러닝 중이면 확인 다이얼로그
  void _onBackPressed() {
    if (_isRunning) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: ctx.colors.surface,
          title: Text('러닝 중단',
              style: TextStyle(color: ctx.colors.textPrimary)),
          content: Text('러닝을 중단하고 나가시겠어요?',
              style: TextStyle(color: ctx.colors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(),
              child: const Text('계속 달리기',
                  style: TextStyle(color: AppTheme.primary)),
            ),
            TextButton(
              onPressed: () async {
                _timer?.cancel();
                _backupTimer?.cancel();
                _backupTimer = null;
                _sampleTimer?.cancel();
                _sampleTimer = null;
                // 사용자가 명시적으로 나가는 경우도 백업 삭제
                await _backup.clear();
                await _positionSubscription?.cancel();
                await _hrDataSource.stop();
                await _notificationService.cancel();
                if (!ctx.mounted) return;
                ctx.pop();
                ctx.go('/home');
              },
              child: const Text('나가기', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } else {
      context.go('/home');
    }
  }
}

// ─── GPS 신호 강도 배지 ─────────────────────────────────────────────────────
// 시작 전 화면 우측 상단 — 좋음(녹색)/보통(노랑)/약함(빨강)/탐색 중(회색)
class _GpsSignalBadge extends ConsumerWidget {
  const _GpsSignalBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSignal = ref.watch(gpsSignalProvider);
    final level = asyncSignal.valueOrNull ?? GpsSignalLevel.unknown;

    final ({Color color, IconData icon, String label}) view = switch (level) {
      GpsSignalLevel.good => (
          color: Colors.green,
          icon: Icons.gps_fixed,
          label: 'GPS 좋음',
        ),
      GpsSignalLevel.ok => (
          color: Colors.orange,
          icon: Icons.gps_not_fixed,
          label: 'GPS 보통',
        ),
      GpsSignalLevel.weak => (
          color: Colors.red,
          icon: Icons.gps_off,
          label: 'GPS 약함',
        ),
      GpsSignalLevel.unknown => (
          color: Colors.grey,
          icon: Icons.gps_not_fixed,
          label: 'GPS 탐색 중',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: view.color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(view.icon, color: view.color, size: 14),
          const SizedBox(width: 6),
          Text(
            view.label,
            style: TextStyle(
              color: view.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 스탯 타일 ────────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// 심박수 타일 (BLE 상태에 따라 다르게 표시)
class _HrStatTile extends StatelessWidget {
  final int hr;
  final BleHrStatus status;

  const _HrStatTile({required this.hr, required this.status});

  @override
  Widget build(BuildContext context) {
    final hrColor = status == BleHrStatus.connected
        ? Colors.redAccent
        : context.colors.textSecondary;
    final value = status == BleHrStatus.connected && hr > 0 ? '$hr' : '--';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (status == BleHrStatus.scanning)
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppTheme.accent),
                )
              else
                Icon(
                  status == BleHrStatus.connected
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: hrColor,
                  size: 12,
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: hrColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '심박수 bpm',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
