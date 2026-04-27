import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

// 회원가입 UseCase
class SignUpUseCase implements UseCase<UserEntity, SignUpParams> {
  final AuthRepository repository;

  SignUpUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(SignUpParams params) {
    return repository.signUpWithEmail(
      email: params.email,
      password: params.password,
      name: params.name,
      marketingConsent: params.marketingConsent,
    );
  }
}

class SignUpParams extends Equatable {
  final String email;
  final String password;
  final String name;
  // [선택] 마케팅 정보 수신 동의 — 미체크라도 가입 가능
  final bool marketingConsent;

  const SignUpParams({
    required this.email,
    required this.password,
    required this.name,
    this.marketingConsent = false,
  });

  @override
  List<Object> get props => [email, password, name, marketingConsent];
}
