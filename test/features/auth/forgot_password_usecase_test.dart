import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/error/failures.dart';
import 'package:runtify/features/auth/domain/entities/user_entity.dart';
import 'package:runtify/features/auth/domain/repositories/auth_repository.dart';
import 'package:runtify/features/auth/domain/usecases/forgot_password_usecase.dart';

// 최소 기능의 Fake — 실제 Firebase 의존 없이 반환값/캡처 흐름 검증용
class _FakeAuthRepository implements AuthRepository {
  Either<Failure, void> resetResult = const Right(null);
  String? capturedEmail;
  int callCount = 0;

  @override
  Future<Either<Failure, void>> sendPasswordReset({
    required String email,
  }) async {
    capturedEmail = email;
    callCount++;
    return resetResult;
  }

  // 아래 메서드들은 본 테스트에서 사용하지 않지만 인터페이스 준수를 위해 유지
  @override
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, UserEntity>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> signOut() => throw UnimplementedError();

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() =>
      throw UnimplementedError();
}

void main() {
  group('ForgotPasswordUseCase', () {
    late _FakeAuthRepository repo;
    late ForgotPasswordUseCase useCase;

    setUp(() {
      repo = _FakeAuthRepository();
      useCase = ForgotPasswordUseCase(repo);
    });

    test('정상 이메일이면 Repository 호출 + Right 반환', () async {
      final result = await useCase(
        const ForgotPasswordParams(email: '  User@Runtify.DEV  '),
      );

      // 정규화된 소문자 + trim 형태로 넘어갔는지 확인
      expect(repo.capturedEmail, 'user@runtify.dev');
      expect(repo.callCount, 1);
      expect(result.isRight(), true);
    });

    test('형식이 잘못된 이메일이면 Repository 미호출 + Left', () async {
      final result = await useCase(
        const ForgotPasswordParams(email: 'not-an-email'),
      );

      expect(repo.callCount, 0);
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (_) => fail('잘못된 형식은 Left를 반환해야 함'),
      );
    });

    test('빈 입력이면 Repository 미호출 + Left', () async {
      final result = await useCase(
        const ForgotPasswordParams(email: '   '),
      );

      expect(repo.callCount, 0);
      expect(result.isLeft(), true);
    });

    test('Repository가 Failure를 반환하면 동일 Failure 전파', () async {
      repo.resetResult = const Left(AuthFailure('네트워크 연결을 확인한 뒤 다시 시도해주세요'));

      final result = await useCase(
        const ForgotPasswordParams(email: 'user@runtify.dev'),
      );

      expect(repo.callCount, 1);
      result.fold(
        (failure) => expect(failure.message, contains('네트워크')),
        (_) => fail('네트워크 에러는 Left로 전파되어야 함'),
      );
    });
  });
}
