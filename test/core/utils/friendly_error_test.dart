import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/utils/friendly_error.dart';

void main() {
  group('friendlyErrorMessage', () {
    test('SocketException 류는 네트워크 안내', () {
      final msg = friendlyErrorMessage(
        Exception('SocketException: failed to connect'),
      );
      expect(msg, contains('네트워크'));
    });

    test('타임아웃은 응답 늦음 안내', () {
      final msg = friendlyErrorMessage(
        Exception('TimeoutException after 0:00:30.000000'),
      );
      expect(msg, contains('응답이'));
      expect(msg, contains('잠시'));
    });

    test('permission-denied 는 권한 안내', () {
      final msg = friendlyErrorMessage(
        Exception('FirebaseException: permission-denied'),
      );
      expect(msg, contains('권한'));
    });

    test('not-found 는 데이터 못 찾음 안내', () {
      final msg = friendlyErrorMessage(
        Exception('FirebaseException: not-found'),
      );
      expect(msg, contains('찾을 수 없'));
    });

    test('인덱스 미배포(failed-precondition) 는 서버 설정 안내', () {
      final msg = friendlyErrorMessage(
        Exception('FAILED_PRECONDITION: requires an index'),
      );
      expect(msg, contains('서버 설정'));
    });

    test('unavailable 은 일시 불안정 안내', () {
      final msg = friendlyErrorMessage(
        Exception('FirebaseException: unavailable'),
      );
      expect(msg, contains('일시적'));
    });

    test('알 수 없는 에러는 generic 안내 (원본 에러 텍스트 노출 안 함)', () {
      final msg = friendlyErrorMessage(
        Exception('Stack trace: secret-internal-state-foo-bar'),
      );
      expect(msg, '잠시 후 다시 시도해주세요');
      expect(msg, isNot(contains('secret-internal-state')));
      expect(msg, isNot(contains('Stack trace')));
    });
  });
}
