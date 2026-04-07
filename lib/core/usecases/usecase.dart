import 'package:dartz/dartz.dart';
import '../error/failures.dart';

// 모든 UseCase가 구현해야 하는 기본 인터페이스
// Output: 반환값 타입, Params: 입력값 타입
abstract class UseCase<Output, Params> {
  Future<Either<Failure, Output>> call(Params params);
}

// 입력값이 없는 UseCase용 (예: 로그아웃, 현재 유저 가져오기)
class NoParams {}
