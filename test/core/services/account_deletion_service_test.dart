import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/services/account_deletion_service.dart';

void main() {
  group('AccountDeletionService — 해시', () {
    test('동일 code + uid → 동일 해시', () {
      final h1 = AccountDeletionService.hashCodeForUserForTest(
        code: '123456',
        uid: 'uid-A',
      );
      final h2 = AccountDeletionService.hashCodeForUserForTest(
        code: '123456',
        uid: 'uid-A',
      );
      expect(h1, h2);
    });

    test('uid 가 다르면 같은 code 라도 해시 다름', () {
      final h1 = AccountDeletionService.hashCodeForUserForTest(
        code: '123456',
        uid: 'uid-A',
      );
      final h2 = AccountDeletionService.hashCodeForUserForTest(
        code: '123456',
        uid: 'uid-B',
      );
      expect(h1, isNot(h2));
    });

    test('code 가 다르면 해시 다름', () {
      final h1 = AccountDeletionService.hashCodeForUserForTest(
        code: '111111',
        uid: 'uid-A',
      );
      final h2 = AccountDeletionService.hashCodeForUserForTest(
        code: '222222',
        uid: 'uid-A',
      );
      expect(h1, isNot(h2));
    });

    test('해시는 SHA256 (64 hex chars)', () {
      final h = AccountDeletionService.hashCodeForUserForTest(
        code: '123456',
        uid: 'uid',
      );
      expect(h.length, 64);
      expect(RegExp(r'^[a-f0-9]+$').hasMatch(h), true);
    });
  });

  group('AccountDeletionService — 정책 상수', () {
    test('codeTtl = 10분', () {
      expect(AccountDeletionService.codeTtl, const Duration(minutes: 10));
    });

    test('codeLength = 6', () {
      expect(AccountDeletionService.codeLength, 6);
    });
  });
}
