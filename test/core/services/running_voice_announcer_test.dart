import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/running_voice_announcer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('formatAnnouncement', () {
    test('기본 — km/페이스/심박 모두 포함', () {
      final s = RunningVoiceAnnouncer.formatAnnouncement(
        km: 3,
        paceMinPerKm: 5.5,
        avgHeartRate: 145,
      );
      expect(s, '3 킬로미터 통과, 페이스 5분 30초, 평균 심박수 145.');
    });

    test('페이스 0이면 페이스 부분 생략', () {
      final s = RunningVoiceAnnouncer.formatAnnouncement(
        km: 1,
        paceMinPerKm: 0,
        avgHeartRate: 130,
      );
      expect(s, '1 킬로미터 통과, 평균 심박수 130.');
    });

    test('심박 0이면 심박 부분 생략', () {
      final s = RunningVoiceAnnouncer.formatAnnouncement(
        km: 5,
        paceMinPerKm: 5.0,
        avgHeartRate: 0,
      );
      expect(s, '5 킬로미터 통과, 페이스 5분.');
    });

    test('페이스 + 심박 둘 다 0이면 km 만', () {
      final s = RunningVoiceAnnouncer.formatAnnouncement(
        km: 2,
        paceMinPerKm: 0,
        avgHeartRate: 0,
      );
      expect(s, '2 킬로미터 통과.');
    });

    test('페이스 정확히 5분이면 초 부분 제거', () {
      final s = RunningVoiceAnnouncer.formatAnnouncement(
        km: 1,
        paceMinPerKm: 5.0,
        avgHeartRate: 130,
      );
      expect(s, '1 킬로미터 통과, 페이스 5분, 평균 심박수 130.');
    });
  });

  group('isEnabled / setEnabled', () {
    test('초기값은 true (기본 ON)', () async {
      expect(await RunningVoiceAnnouncer.isEnabled(), true);
    });

    test('setEnabled(false) 후 isEnabled false', () async {
      await RunningVoiceAnnouncer.setEnabled(false);
      expect(await RunningVoiceAnnouncer.isEnabled(), false);
    });

    test('setEnabled(true) 후 isEnabled true', () async {
      await RunningVoiceAnnouncer.setEnabled(false);
      await RunningVoiceAnnouncer.setEnabled(true);
      expect(await RunningVoiceAnnouncer.isEnabled(), true);
    });
  });
}
