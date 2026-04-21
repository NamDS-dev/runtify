import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/user_entity.dart';

// Auth 관련 데이터 조작의 인터페이스 (추상)
// Data 레이어에서 구현체를 만들어야 함
abstract class AuthRepository {
  // 이메일/비밀번호 로그인
  Future<Either<Failure, UserEntity>> signInWithEmail({
    required String email,
    required String password,
  });

  // 이메일/비밀번호 회원가입
  Future<Either<Failure, UserEntity>> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  });

  // 로그아웃
  Future<Either<Failure, void>> signOut();

  // 현재 로그인된 유저 가져오기
  Future<Either<Failure, UserEntity?>> getCurrentUser();

  // 비밀번호 재설정 메일 발송
  // 보안: user-not-found 를 성공과 구분하지 않아 계정 존재 힌트를 차단한다.
  Future<Either<Failure, void>> sendPasswordReset({required String email});
}
