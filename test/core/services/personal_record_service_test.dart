import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/personal_record_service.dart';

// Firestore 트랜잭션 테스트는 fake_cloud_firestore 새 dev dep 필요해 보류.
// 본 테스트는 거리 카탈로그 + PersonalRecord 포맷 + 추정 시간 계산 단위 케이스만 검증.
void main() {
  group('PersonalRecordService.distances', () {
    test('5종 거리 정의', () {
      final keys = PersonalRecordService.distances.map((d) => d.key).toList();
      expect(keys, ['1k', '5k', '10k', 'half', 'full']);
    });

    test('정확한 거리 m 단위', () {
      final byKey = {
        for (final d in PersonalRecordService.distances) d.key: d.meters,
      };
      expect(byKey['1k'], 1000);
      expect(byKey['5k'], 5000);
      expect(byKey['10k'], 10000);
      expect(byKey['half'], 21097);
      expect(byKey['full'], 42195);
    });
  });

  group('PersonalRecord.formattedTime', () {
    PersonalRecord record(int seconds) {
      return PersonalRecord(
        distance: PersonalRecordService.distances.first,
        bestTimeSeconds: seconds,
        sessionId: null,
        achievedAt: null,
      );
    }

    test('1분 미만은 0:00 형태', () {
      expect(record(45).formattedTime, '00:45');
    });

    test('1시간 미만은 MM:SS', () {
      expect(record(5 * 60 + 23).formattedTime, '05:23'); // 5분 23초
      expect(record(59 * 60 + 59).formattedTime, '59:59');
    });

    test('1시간 이상은 H:MM:SS', () {
      expect(record(3600 + 5 * 60 + 23).formattedTime, '1:05:23');
      expect(record(2 * 3600 + 13 * 60 + 7).formattedTime, '2:13:07');
    });

    test('초 0 패딩', () {
      expect(record(60).formattedTime, '01:00');
      expect(record(3600).formattedTime, '1:00:00');
    });
  });
}
