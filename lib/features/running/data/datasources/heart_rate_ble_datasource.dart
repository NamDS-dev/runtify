import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// BLE 심박수 연결 상태
enum BleHrStatus { disconnected, scanning, connected }

// 갤럭시 워치(또는 BLE 심박수 기기)에서 실시간 심박수를 가져오는 데이터소스
// 데이터 흐름: 갤럭시 워치 BLE → HeartRateBleDataSource → RunningPage
//
// 갤럭시 워치가 BLE HRM을 브로드캐스트하려면:
// 삼성 헬스 앱 → 설정 → 연결된 서비스 → Bluetooth 활성화 필요
class HeartRateBleDataSource {
  // 표준 Bluetooth SIG Heart Rate 서비스 / Characteristic UUID (16-bit 형식)
  static const String _hrServiceUuid = '180d';
  static const String _hrCharUuid = '2a37';

  BluetoothDevice? _device;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _hrSub;

  final _statusController = StreamController<BleHrStatus>.broadcast();
  final _hrController = StreamController<int>.broadcast();

  Stream<BleHrStatus> get statusStream => _statusController.stream;
  Stream<int> get heartRateStream => _hrController.stream;

  // BLE 심박수 기기 스캔 시작 (Heart Rate 서비스를 광고하는 기기만 탐색)
  Future<void> startScan() async {
    if (kIsWeb) {
      // 웹에서는 BLE 미지원 → disconnected 상태로 즉시 반환
      _statusController.add(BleHrStatus.disconnected);
      return;
    }
    try {
      // BLE 지원 여부 확인 (에뮬레이터, 구형 기기 대응)
      if (!await FlutterBluePlus.isSupported) {
        _statusController.add(BleHrStatus.disconnected);
        return;
      }

      _statusController.add(BleHrStatus.scanning);

      // Heart Rate 서비스(0x180D)를 광고하는 기기만 필터링해서 스캔
      await FlutterBluePlus.startScan(
        withServices: [Guid(_hrServiceUuid)],
        timeout: const Duration(seconds: 20),
      );

      _scanSub = FlutterBluePlus.onScanResults.listen((results) async {
        if (results.isNotEmpty && _device == null) {
          // 첫 번째로 발견된 HRM 기기에 연결
          final device = results.first.device;
          await FlutterBluePlus.stopScan();
          await _connectToDevice(device);
        }
      });

      // 20초 스캔 후 기기를 찾지 못하면 disconnected로 전환
      FlutterBluePlus.isScanning.listen((isScanning) {
        if (!isScanning && _device == null) {
          _statusController.add(BleHrStatus.disconnected);
        }
      });
    } catch (e) {
      // 권한 거부, BT 꺼짐 등 예외 → 조용히 실패 (HR만 없는 상태로 러닝 계속)
      _statusController.add(BleHrStatus.disconnected);
    }
  }

  // BLE 기기에 연결하고 Heart Rate Measurement Characteristic 구독
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(
        license: License.free, // 개인 프로젝트는 free 라이선스
        autoConnect: false,
        timeout: const Duration(seconds: 10),
      );
      _device = device;

      // 연결 끊김 감지 (워치 멀어짐, BT 꺼짐 등)
      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _device = null;
          _statusController.add(BleHrStatus.disconnected);
        }
      });

      // Heart Rate 서비스 탐색
      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid.toString().toLowerCase().contains(_hrServiceUuid)) {
          for (final char in service.characteristics) {
            if (char.uuid.toString().toLowerCase().contains(_hrCharUuid)) {
              // Heart Rate 값 변경 알림 구독
              _hrSub = char.onValueReceived.listen((value) {
                if (value.length >= 2) {
                  _hrController.add(_parseHeartRate(value));
                }
              });
              await char.setNotifyValue(true);
              _statusController.add(BleHrStatus.connected);
              return;
            }
          }
        }
      }

      // HR 서비스를 찾지 못한 경우 (워치이지만 HRM 미지원 또는 설정 필요)
      await device.disconnect();
      _device = null;
      _statusController.add(BleHrStatus.disconnected);
    } catch (e) {
      _device = null;
      _statusController.add(BleHrStatus.disconnected);
    }
  }

  // BLE Heart Rate Measurement 값 파싱 (Bluetooth SIG Core Spec 표준)
  // value[0] = flags, bit0=0: HR은 uint8, bit0=1: HR은 uint16
  int _parseHeartRate(List<int> value) {
    final flags = value[0];
    if (flags & 0x01 == 0) {
      return value[1]; // uint8 형식
    } else {
      return value[1] | (value[2] << 8); // uint16 little-endian
    }
  }

  // 스캔/연결 중단 및 리소스 정리
  Future<void> stop() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    await _hrSub?.cancel();
    await _connectionSub?.cancel();
    try {
      await _device?.disconnect();
    } catch (_) {}
    _scanSub = null;
    _hrSub = null;
    _connectionSub = null;
    _device = null;
  }

  void dispose() {
    stop();
    _statusController.close();
    _hrController.close();
  }
}
