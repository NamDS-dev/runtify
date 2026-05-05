import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/providers/gps_signal_provider.dart';

void main() {
  group('classifyAccuracy', () {
    test('5m → good', () {
      expect(classifyAccuracy(5), GpsSignalLevel.good);
    });

    test('정확히 10m → good (포함)', () {
      expect(classifyAccuracy(10), GpsSignalLevel.good);
    });

    test('15m → ok', () {
      expect(classifyAccuracy(15), GpsSignalLevel.ok);
    });

    test('정확히 25m → ok (포함)', () {
      expect(classifyAccuracy(25), GpsSignalLevel.ok);
    });

    test('30m → weak', () {
      expect(classifyAccuracy(30), GpsSignalLevel.weak);
    });

    test('100m → weak', () {
      expect(classifyAccuracy(100), GpsSignalLevel.weak);
    });

    test('0m (이상 fix) → good', () {
      expect(classifyAccuracy(0), GpsSignalLevel.good);
    });
  });
}
