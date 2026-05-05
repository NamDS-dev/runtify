import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/running_backup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RunningBackupSnapshot 직렬화', () {
    test('toJson/fromJson 라운드트립', () {
      final original = RunningBackupSnapshot(
        startTime: DateTime.utc(2026, 5, 5, 22, 30),
        distanceKm: 3.45,
        durationSeconds: 1234,
        avgHeartRate: 145.5,
        routePoints: [
          [37.5665, 126.9780],
          [37.5670, 126.9785],
        ],
        splitPaces: [
          [1.0, 5.5],
          [2.0, 5.7],
        ],
        lastLat: 37.5670,
        lastLng: 126.9785,
        firstLat: 37.5665,
        firstLng: 126.9780,
      );

      final restored = RunningBackupSnapshot.fromJson(original.toJson());
      expect(restored, isNotNull);
      expect(restored!.startTime, original.startTime);
      expect(restored.distanceKm, original.distanceKm);
      expect(restored.durationSeconds, original.durationSeconds);
      expect(restored.avgHeartRate, original.avgHeartRate);
      expect(restored.routePoints, original.routePoints);
      expect(restored.splitPaces, original.splitPaces);
      expect(restored.lastLat, original.lastLat);
      expect(restored.lastLng, original.lastLng);
    });

    test('손상된 JSON은 null 반환', () {
      expect(RunningBackupSnapshot.fromJson({'invalid': 'data'}), isNull);
    });

    test('isRecoverable — 0.05km/30초 미만은 false', () {
      final tiny = RunningBackupSnapshot(
        startTime: DateTime.now(),
        distanceKm: 0.05,
        durationSeconds: 20,
        avgHeartRate: 0,
        routePoints: const [],
        splitPaces: const [],
      );
      expect(tiny.isRecoverable, false);
    });

    test('isRecoverable — 0.1km + 60초 이상은 true', () {
      final ok = RunningBackupSnapshot(
        startTime: DateTime.now(),
        distanceKm: 0.5,
        durationSeconds: 120,
        avgHeartRate: 130,
        routePoints: const [],
        splitPaces: const [],
      );
      expect(ok.isRecoverable, true);
    });
  });

  group('RunningBackup 영속화', () {
    test('초기 상태는 빈 백업', () async {
      final backup = RunningBackup();
      expect(await backup.load(), isNull);
    });

    test('save 후 load 동일 데이터', () async {
      final backup = RunningBackup();
      final snap = RunningBackupSnapshot(
        startTime: DateTime.utc(2026, 5, 5, 22, 30),
        distanceKm: 2.5,
        durationSeconds: 600,
        avgHeartRate: 140,
        routePoints: [
          [37.5, 127.0],
        ],
        splitPaces: [
          [1.0, 5.0],
          [2.0, 5.5],
        ],
        lastLat: 37.5,
        lastLng: 127.0,
      );
      await backup.save(snap);

      final loaded = await backup.load();
      expect(loaded, isNotNull);
      expect(loaded!.distanceKm, 2.5);
      expect(loaded.durationSeconds, 600);
      expect(loaded.routePoints.length, 1);
      expect(loaded.splitPaces.length, 2);
    });

    test('clear 후 load 는 null', () async {
      final backup = RunningBackup();
      await backup.save(RunningBackupSnapshot(
        startTime: DateTime.now(),
        distanceKm: 1.0,
        durationSeconds: 300,
        avgHeartRate: 0,
        routePoints: const [],
        splitPaces: const [],
      ));
      await backup.clear();
      expect(await backup.load(), isNull);
    });

    test('손상된 raw 데이터는 load 시 null 반환', () async {
      SharedPreferences.setMockInitialValues({
        RunningBackup.storageKey: '{not valid json',
      });
      final backup = RunningBackup();
      expect(await backup.load(), isNull);
    });
  });
}
