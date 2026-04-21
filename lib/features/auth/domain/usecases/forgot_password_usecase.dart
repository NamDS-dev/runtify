import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/validators/email_validator.dart';
import '../repositories/auth_repository.dart';

// 비밀번호 재설정 메일 발송 UseCase
// 보안 원칙:
// - user-not-found 를 성공과 구분해 노출하지 않음 (계정 존재 힌트 차단)
// - 네트워크·입력 형식 오류만 실패로 구분해 사용자에게 재시도를 유도
class ForgotPasswordUseCase implements UseCase<void, ForgotPasswordParams> {
  final AuthRepository repository;

  ForgotPasswordUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(ForgotPasswordParams params) async {
    final normalized = EmailValidator.normalize(params.email);
    final error = EmailValidator.validate(normalized);
    if (error != null) {
      return Left(AuthFailure(error));
    }
    return repository.sendPasswordReset(email: normalized);
  }
}

class ForgotPasswordParams extends Equatable {
  final String email;

  const ForgotPasswordParams({required this.email});

  @override
  List<Object> get props => [email];
}
