import '../repositories/crew_repository.dart';

// 크루 가입 파라미터
class JoinCrewParams {
  final String crewId;
  final String userId;

  const JoinCrewParams({required this.crewId, required this.userId});
}

// 크루 가입 유스케이스 — 1인 1크루 제한은 Firestore 트랜잭션에서 처리
class JoinCrewUseCase {
  final CrewRepository _repository;

  const JoinCrewUseCase(this._repository);

  Future<void> call(JoinCrewParams params) => _repository.joinCrew(
        crewId: params.crewId,
        userId: params.userId,
      );
}
