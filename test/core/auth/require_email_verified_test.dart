import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtify/core/auth/require_email_verified.dart';
import 'package:runtify/core/error/failures.dart';
import 'package:runtify/core/services/login_rate_limiter.dart';
import 'package:runtify/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:runtify/features/auth/data/models/user_model.dart';
import 'package:runtify/features/auth/domain/entities/user_entity.dart';
import 'package:runtify/features/auth/domain/repositories/auth_repository.dart';
import 'package:runtify/features/auth/domain/usecases/forgot_password_usecase.dart';
import 'package:runtify/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:runtify/features/auth/domain/usecases/sign_up_usecase.dart';
import 'package:runtify/features/auth/presentation/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 다이얼로그 흐름은 위젯 테스트로 검증하기 무겁기 때문에,
// 헬퍼의 핵심 분기(이미 인증됨 / 비로그인)만 가벼운 위젯 트리에서 검증한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<bool?> runHelperWith(
    WidgetTester tester,
    UserEntity? user,
  ) async {
    bool? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => _StubAuthNotifier(
              user == null
                  ? const AsyncValue<UserEntity?>.data(null)
                  : AsyncValue<UserEntity?>.data(user),
            ),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await requireEmailVerified(context, ref);
                  },
                  child: const Text('try'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('try'));
    await tester.pump();
    return result;
  }

  group('requireEmailVerified', () {
    testWidgets('인증된 사용자는 즉시 true 반환', (tester) async {
      const verified = UserEntity(
        id: 'u1',
        name: 'Verified User',
        email: 'v@runtify.dev',
        emailVerified: true,
      );
      final result = await runHelperWith(tester, verified);
      expect(result, true);
    });

    testWidgets('로그인 안 된 상태는 즉시 false 반환', (tester) async {
      final result = await runHelperWith(tester, null);
      expect(result, false);
    });
  });
}

// AuthNotifier 의 의존 객체를 모두 무동작으로 채운 stub 노티파이어.
// _checkCurrentUser 가 _dataSource.getCurrentUser() 를 호출하지만 _NoOpDataSource 가 null 을 반환해 안전.
class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(AsyncValue<UserEntity?> initial)
      : super(
          dataSource: _NoOpDataSource(),
          signInUseCase: SignInUseCase(_NoOpRepository()),
          signUpUseCase: SignUpUseCase(_NoOpRepository()),
          forgotPasswordUseCase: ForgotPasswordUseCase(_NoOpRepository()),
          rateLimiter: LoginRateLimiter(),
        ) {
    state = initial;
  }
}

class _NoOpDataSource implements AuthRemoteDataSource {
  @override
  Future<UserModel?> getCurrentUser() async => null;

  @override
  Future<UserModel> signInWithEmail(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<UserModel> signUpWithEmail(
    String email,
    String password,
    String name, {
    bool marketingConsent = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<UserModel> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<UserModel> signInWithApple() => throw UnimplementedError();

  @override
  Future<void> signOut() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class _NoOpRepository implements AuthRepository {
  @override
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      Left(const AuthFailure('noop'));

  @override
  Future<Either<Failure, UserEntity>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
    bool marketingConsent = false,
  }) async =>
      Left(const AuthFailure('noop'));

  @override
  Future<Either<Failure, void>> signOut() async => const Right(null);

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> sendPasswordReset({
    required String email,
  }) async =>
      const Right(null);
}
