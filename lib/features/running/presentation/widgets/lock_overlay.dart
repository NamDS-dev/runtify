import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// 위로 길게 스와이프 동작 추적기 — 단위 테스트 친화 형태로 분리.
///
/// 해제 조건: 누적 dy(위로 이동량) ≥ [unlockDistancePx] AND
///           드래그 시작 ~ 현재 경과 시간 ≥ [unlockHoldDuration].
class LockSwipeTracker {
  final double unlockDistancePx;
  final Duration unlockHoldDuration;

  DateTime? _startedAt;
  double _accumulatedUpwardDy = 0;

  LockSwipeTracker({
    this.unlockDistancePx = 100,
    this.unlockHoldDuration = const Duration(seconds: 2),
  });

  bool get isTracking => _startedAt != null;

  void start(DateTime now) {
    _startedAt = now;
    _accumulatedUpwardDy = 0;
  }

  /// 화면 좌표계는 위쪽이 음수. 양수 dy(아래로 이동) 시 진행 리셋.
  void update(double dy) {
    if (_startedAt == null) return;
    if (dy >= 0) {
      // 아래로 이동 = 사용자가 잠금 해제 의도 X — 추적 리셋
      reset();
      return;
    }
    _accumulatedUpwardDy += -dy; // 양수 누적
  }

  void reset() {
    _startedAt = null;
    _accumulatedUpwardDy = 0;
  }

  /// 해제 조건 충족 여부 — 거리 + 유지 시간 둘 다 만족해야 true.
  bool shouldUnlock(DateTime now) {
    if (_startedAt == null) return false;
    if (_accumulatedUpwardDy < unlockDistancePx) return false;
    return now.difference(_startedAt!) >= unlockHoldDuration;
  }

  /// 진행률 (0.0 ~ 1.0) — 안내 UI 게이지용. 거리·시간 조건 중 작은 쪽 기준.
  double progress(DateTime now) {
    if (_startedAt == null) return 0.0;
    final distRatio = (_accumulatedUpwardDy / unlockDistancePx).clamp(0.0, 1.0);
    final timeRatio = (now.difference(_startedAt!).inMilliseconds /
            unlockHoldDuration.inMilliseconds)
        .clamp(0.0, 1.0);
    return distRatio < timeRatio ? distRatio : timeRatio;
  }
}

/// 러닝 중 실수 터치 방지 — 화면 잠금 오버레이.
///
/// 활성화되면 하위 위젯 터치를 모두 차단(`IgnorePointer`)하고,
/// 자체 [GestureDetector]로 위로 길게 스와이프(2초+ / 100px+) 시 [onUnlock] 호출.
class LockOverlay extends StatefulWidget {
  final VoidCallback onUnlock;

  const LockOverlay({super.key, required this.onUnlock});

  @override
  State<LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends State<LockOverlay> {
  late final LockSwipeTracker _tracker;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _tracker = LockSwipeTracker();
  }

  void _refreshProgress() {
    final p = _tracker.progress(DateTime.now());
    if (p != _progress) {
      setState(() => _progress = p);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) {
        _tracker.start(DateTime.now());
        _refreshProgress();
      },
      onVerticalDragUpdate: (details) {
        _tracker.update(details.delta.dy);
        if (_tracker.shouldUnlock(DateTime.now())) {
          _tracker.reset();
          widget.onUnlock();
          return;
        }
        _refreshProgress();
      },
      onVerticalDragEnd: (_) {
        _tracker.reset();
        if (_progress != 0) {
          setState(() => _progress = 0);
        }
      },
      onVerticalDragCancel: () {
        _tracker.reset();
        if (_progress != 0) {
          setState(() => _progress = 0);
        }
      },
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              const Text(
                '잠금 중',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '위로 길게 스와이프하여 잠금 해제 (2초)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 6,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(AppTheme.primary),
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
