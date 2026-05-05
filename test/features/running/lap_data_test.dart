import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/features/running/domain/entities/lap_data.dart';

void main() {
  group('LapData', () {
    test('toJson/fromJson 라운드트립', () {
      const lap = LapData(km: 3, splitSeconds: 320, pace: 5.33, avgHeartRate: 145.5);
      final j = lap.toJson();
      final restored = LapData.fromJson(j);
      expect(restored.km, lap.km);
      expect(restored.splitSeconds, lap.splitSeconds);
      expect(restored.pace, lap.pace);
      expect(restored.avgHeartRate, lap.avgHeartRate);
    });

    test('formattedSplitTime — 5분 20초', () {
      const lap = LapData(km: 1, splitSeconds: 320, pace: 5.33);
      expect(lap.formattedSplitTime, '05:20');
    });

    test('formattedSplitTime — 9초', () {
      const lap = LapData(km: 1, splitSeconds: 9, pace: 0.15);
      expect(lap.formattedSplitTime, '00:09');
    });

    test('formattedPace — 5분 30초/km', () {
      const lap = LapData(km: 1, splitSeconds: 330, pace: 5.5);
      expect(lap.formattedPace, "5'30\"");
    });

    test('formattedPace — 0이면 placeholder', () {
      const lap = LapData(km: 1, splitSeconds: 0, pace: 0);
      expect(lap.formattedPace, "--'--\"");
    });

    test('avgHeartRate 누락된 JSON도 정상 처리', () {
      final lap = LapData.fromJson({'km': 1, 'splitSeconds': 300, 'pace': 5.0});
      expect(lap.avgHeartRate, 0.0);
    });
  });
}
