import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/features/running/domain/entities/running_sample.dart';

void main() {
  group('RunningSample', () {
    test('toJson/fromJson 라운드트립', () {
      const sample = RunningSample(
        elapsedSeconds: 120,
        paceMinPerKm: 5.5,
        altitudeM: 35.4,
        heartRate: 145,
      );
      final restored = RunningSample.fromJson(sample.toJson());
      expect(restored, sample);
    });

    test('빠진 필드는 0으로 복원', () {
      final s = RunningSample.fromJson({'elapsedSeconds': 60});
      expect(s.elapsedSeconds, 60);
      expect(s.paceMinPerKm, 0.0);
      expect(s.altitudeM, 0.0);
      expect(s.heartRate, 0.0);
    });

    test('Equatable — 동일 값은 같음', () {
      const a = RunningSample(
          elapsedSeconds: 10, paceMinPerKm: 5, altitudeM: 0, heartRate: 0);
      const b = RunningSample(
          elapsedSeconds: 10, paceMinPerKm: 5, altitudeM: 0, heartRate: 0);
      expect(a, b);
    });
  });
}
