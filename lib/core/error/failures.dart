import 'package:equatable/equatable.dart';

// 앱 전체에서 사용하는 에러 타입 정의
abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

// Firebase 인증 에러
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

// Firestore DB 에러
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

// 네트워크 에러
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

// 웨어러블 기기 에러
class WearableFailure extends Failure {
  const WearableFailure(super.message);
}
