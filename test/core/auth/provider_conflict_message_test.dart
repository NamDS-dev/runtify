import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/auth/provider_conflict_message.dart';

void main() {
  group('providerConflictMessage', () {
    test('Google 가입자는 Google 안내', () {
      final msg = providerConflictMessage(['google.com']);
      expect(msg, contains('Google'));
      expect(msg, contains('가입돼'));
    });

    test('Apple 가입자는 Apple 안내', () {
      final msg = providerConflictMessage(['apple.com']);
      expect(msg, contains('Apple'));
    });

    test('비밀번호 가입자는 비밀번호 안내', () {
      final msg = providerConflictMessage(['password']);
      expect(msg, contains('비밀번호'));
    });

    test('빈 list는 generic 안내', () {
      final msg = providerConflictMessage([]);
      expect(msg, contains('다른 로그인 방식'));
    });

    test('알 수 없는 provider는 generic 안내', () {
      final msg = providerConflictMessage(['microsoft.com']);
      expect(msg, contains('다른 로그인 방식'));
    });

    test('여러 provider 연결 — 소셜 우선 (Google이 비밀번호보다 먼저)', () {
      final msg = providerConflictMessage(['password', 'google.com']);
      expect(msg, contains('Google'));
      expect(msg.contains('비밀번호로 가입'), false);
    });

    test('여러 provider — Google이 Apple보다 먼저', () {
      final msg = providerConflictMessage(['apple.com', 'google.com']);
      expect(msg, contains('Google'));
    });
  });
}
