import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/utils/firebase_timeout.dart';

void main() {
  group('withFirebaseTimeout', () {
    test('정상 완료 → 결과 반환', () async {
      final result = await withFirebaseTimeout(
        Future.value('ok'),
        operation: 'test',
      );
      expect(result, 'ok');
    });

    test('timeout 초과 → FirebaseTimeoutException', () async {
      // 절대 완료 안 되는 future
      final stuck = Completer<String>().future;
      await expectLater(
        withFirebaseTimeout(
          stuck,
          operation: 'stuck_op',
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<FirebaseTimeoutException>()),
      );
    });

    test('FirebaseTimeoutException — operation 포함', () async {
      final stuck = Completer<String>().future;
      try {
        await withFirebaseTimeout(
          stuck,
          operation: 'getRecentSessions',
          timeout: const Duration(milliseconds: 30),
        );
        fail('should throw');
      } on FirebaseTimeoutException catch (e) {
        expect(e.operation, 'getRecentSessions');
        expect(e.duration.inMilliseconds, 30);
      }
    });

    test('FirebaseTimeoutException.userMessage 한국어', () {
      const ex = FirebaseTimeoutException(
        operation: 'test',
        duration: Duration(seconds: 30),
      );
      expect(ex.userMessage, contains('네트워크'));
      expect(ex.userMessage.isNotEmpty, true);
    });

    test('내부 future 가 timeout 전에 throw 하면 그 예외 전파', () async {
      await expectLater(
        withFirebaseTimeout(
          Future.error(StateError('inner')),
          operation: 'test',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
