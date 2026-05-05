import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/features/running/presentation/widgets/lock_overlay.dart';

void main() {
  group('LockSwipeTracker', () {
    late LockSwipeTracker tracker;
    DateTime now = DateTime(2026, 5, 5, 23, 0, 0);

    setUp(() {
      tracker = LockSwipeTracker();
      now = DateTime(2026, 5, 5, 23, 0, 0);
    });

    test('초기 상태: 추적 안 함', () {
      expect(tracker.isTracking, false);
      expect(tracker.shouldUnlock(now), false);
    });

    test('start 후 isTracking true', () {
      tracker.start(now);
      expect(tracker.isTracking, true);
    });

    test('100px 위로 스와이프 + 2초 경과 → 해제', () {
      tracker.start(now);
      // 위로 120px 스와이프 (dy 음수)
      for (int i = 0; i < 12; i++) {
        tracker.update(-10);
      }
      expect(tracker.shouldUnlock(now), false); // 시간 부족

      now = now.add(const Duration(seconds: 2, milliseconds: 1));
      expect(tracker.shouldUnlock(now), true);
    });

    test('거리만 충족 + 시간 부족 → 해제 X', () {
      tracker.start(now);
      tracker.update(-150);
      now = now.add(const Duration(seconds: 1));
      expect(tracker.shouldUnlock(now), false);
    });

    test('시간만 충족 + 거리 부족 → 해제 X', () {
      tracker.start(now);
      tracker.update(-50);
      now = now.add(const Duration(seconds: 3));
      expect(tracker.shouldUnlock(now), false);
    });

    test('아래로 스와이프(dy 양수) 시 추적 리셋', () {
      tracker.start(now);
      tracker.update(-80);
      tracker.update(20); // 아래로 이동 → 리셋
      expect(tracker.isTracking, false);
    });

    test('reset 후 추적 중단', () {
      tracker.start(now);
      tracker.update(-100);
      tracker.reset();
      now = now.add(const Duration(seconds: 5));
      expect(tracker.shouldUnlock(now), false);
    });

    test('progress 는 거리·시간 중 작은 쪽 기준', () {
      tracker.start(now);
      tracker.update(-50); // 거리 50%
      now = now.add(const Duration(seconds: 1)); // 시간 50%
      expect(tracker.progress(now), closeTo(0.5, 0.01));

      tracker.update(-100); // 거리 100%+
      now = now.add(const Duration(milliseconds: 500)); // 시간 75%
      expect(tracker.progress(now), closeTo(0.75, 0.01));
    });

    test('progress 추적 안 할 때 0', () {
      expect(tracker.progress(now), 0.0);
    });
  });
}
