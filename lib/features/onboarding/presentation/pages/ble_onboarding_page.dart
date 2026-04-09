// BLE 심박수 연결 온보딩 — 갤럭시 워치 BLE 페어링
// 스캔 → 기기 목록 → 연결 → 완료

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';

class BleOnboardingPage extends StatefulWidget {
  const BleOnboardingPage({super.key});

  @override
  State<BleOnboardingPage> createState() => _BleOnboardingPageState();
}

class _BleOnboardingPageState extends State<BleOnboardingPage> {
  // Heart Rate 서비스 UUID
  static const String _hrServiceUuid = '180d';

  bool _isScanning = false;
  bool _isConnecting = false;
  final List<ScanResult> _scanResults = [];
  StreamSubscription<List<ScanResult>>? _scanSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _startScan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  // BLE 스캔 시작
  Future<void> _startScan() async {
    if (kIsWeb) return;

    try {
      if (!await FlutterBluePlus.isSupported) return;

      setState(() {
        _isScanning = true;
        _scanResults.clear();
      });

      // Heart Rate 서비스를 광고하는 기기만 스캔
      await FlutterBluePlus.startScan(
        withServices: [Guid(_hrServiceUuid)],
        timeout: const Duration(seconds: 15),
      );

      _scanSub = FlutterBluePlus.onScanResults.listen((results) {
        if (!mounted) return;
        setState(() {
          // 중복 제거하여 목록 갱신
          for (final result in results) {
            final exists = _scanResults.any(
              (r) => r.device.remoteId == result.device.remoteId,
            );
            if (!exists) _scanResults.add(result);
          }
        });
      });

      // 스캔 완료 감지
      FlutterBluePlus.isScanning.listen((scanning) {
        if (!scanning && mounted) {
          setState(() => _isScanning = false);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  // 기기 연결
  Future<void> _connectToDevice(ScanResult result) async {
    setState(() => _isConnecting = true);

    try {
      await result.device.connect(
        license: License.free,
        autoConnect: false,
        timeout: const Duration(seconds: 10),
      );

      // 연결 성공 → 저장 후 완료
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ble_device_id', result.device.remoteId.str);
      await prefs.setString('ble_device_name', result.device.platformName);
      await prefs.setBool('ble_onboarding_done', true);

      // 연결 해제 (온보딩에서는 연결 확인만, 실제 연결은 러닝 시)
      await result.device.disconnect();

      if (mounted) {
        setState(() {
          _isConnecting = false;
        });

        // 성공 스낵바 + 홈 이동
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.device.platformName} 연결 확인 완료!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '연결에 실패했습니다. 다시 시도해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFFF3333),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
    }
  }

  // 건너뛰기
  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ble_onboarding_done', true);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    // 웹 환경
    if (kIsWeb) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⌚', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              Text(
                'BLE 심박수 연결은\n모바일에서만 사용할 수 있습니다',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('홈으로'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),

              // 제목
              const Text(
                '❤️ 실시간 심박수 연결',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                '갤럭시 워치의 심박수를 러닝 중\n실시간으로 표시합니다',
                style: TextStyle(color: context.colors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),

              // 스캔 상태
              Row(
                children: [
                  Text(
                    _isScanning ? '주변 기기 검색 중...' : '검색 완료',
                    style: TextStyle(
                      color: _isScanning ? AppTheme.primary : context.colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_isScanning) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                    ),
                  ],
                  const Spacer(),
                  if (!_isScanning)
                    GestureDetector(
                      onTap: _startScan,
                      child: const Text('다시 검색', style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // 기기 목록
              Expanded(
                child: _scanResults.isEmpty && !_isScanning
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('⌚', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 16),
                            Text(
                              '심박수 기기를 찾지 못했어요',
                              style: TextStyle(color: context.colors.textSecondary, fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '워치의 삼성 헬스 앱이 실행 중인지\n확인해주세요',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _scanResults.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final result = _scanResults[index];
                          final name = result.device.platformName.isNotEmpty
                              ? result.device.platformName
                              : 'Unknown Device';
                          final rssi = result.rssi;
                          final signalStrength = rssi > -60 ? '신호 강함' : rssi > -80 ? '신호 보통' : '신호 약함';

                          return GestureDetector(
                            onTap: _isConnecting ? null : () => _connectToDevice(result),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: rssi > -60 ? context.colors.cardColor : context.colors.surface,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '⌚ $name',
                                          style: TextStyle(
                                            color: rssi > -60 ? Colors.white : context.colors.textSecondary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$signalStrength · Heart Rate Service',
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _isConnecting
                                      ? const SizedBox(
                                          width: 20, height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                                        )
                                      : Text(
                                          '연결',
                                          style: TextStyle(
                                            color: rssi > -60 ? AppTheme.primary : Colors.grey.shade600,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // 힌트
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  '💡 워치의 삼성 헬스 앱이 실행 중이어야\n    심박수 서비스가 검색됩니다',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ),

              // 나중에 하기
              Center(
                child: GestureDetector(
                  onTap: _skip,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Text('나중에 하기', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
