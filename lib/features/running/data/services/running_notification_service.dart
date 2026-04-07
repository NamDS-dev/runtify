import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 러닝 중 갤럭시 워치에 실시간 데이터를 표시하는 알림 서비스
// 작동 원리: 안드로이드 알림 → 갤럭시 워치 자동 포워딩
//
// 워치 화면에 표시되는 내용:
//   RUNTIFY 🏃
//   2.34 km · 6'12"/km
//   ❤ 145 bpm · 00:14:22
class RunningNotificationService {
  static const int _notificationId = 1001;
  static const String _channelId = 'runtify_running';
  static const String _channelName = 'Runtify 러닝 트래킹';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  // Android 13+ 알림 권한 요청
  Future<bool> requestPermission() async {
    await init();
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.requestNotificationsPermission() ?? false;
  }

  // 러닝 진행 중 알림 표시 (1초마다 업데이트 → 워치 화면에 실시간 반영)
  Future<void> update({
    required double distanceKm,
    required int elapsedSeconds,
    required String pace,
    required int heartRate,
  }) async {
    await init();

    final hrLine = heartRate > 0 ? '❤ $heartRate bpm · ' : '';
    final timeStr = _formatTime(elapsedSeconds);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: '러닝 중 실시간 거리, 페이스, 심박수 표시',
      importance: Importance.low, // 소리/진동 없이 조용히 표시
      priority: Priority.low,
      ongoing: true,        // 사용자가 직접 닫을 수 없음 (러닝 종료 시 자동 해제)
      onlyAlertOnce: true,  // 첫 표시 이후 업데이트는 소리 없음
      showWhen: false,
      playSound: false,
      enableVibration: false,
    );

    await _plugin.show(
      _notificationId,
      'RUNTIFY  🏃  ${distanceKm.toStringAsFixed(2)} km',
      '$hrLine페이스 $pace · $timeStr',
      NotificationDetails(android: androidDetails),
    );
  }

  // 러닝 종료 시 알림 제거
  Future<void> cancel() async {
    await _plugin.cancel(_notificationId);
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
