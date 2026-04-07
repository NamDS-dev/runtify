import '../repositories/crew_repository.dart';

// 크루 탈퇴 파라미터
class LeaveCrewParams {
  final String crewId;
  final String userId;

  const LeaveCrewParams({required this.crewId, required this.userId});
}

// 크루 탈퇴 유스케이스 — 크루장 탈퇴 방지는 UI 레이어(crew_detail_page)에서 처리
class LeaveCrewUseCase {
  final CrewRepository _repository;

  const LeaveCrewUseCase(this._repository);

  Future<void> call(LeaveCrewParams params) => _repository.leaveCrew(
        crewId: params.crewId,
        userId: params.userId,
      );
}
