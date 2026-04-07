import '../entities/crew_entity.dart';
import '../repositories/crew_repository.dart';

// 크루 생성 파라미터
class CreateCrewParams {
  final String name;
  final String region;
  final String description;
  final int maxMembers;
  final String leaderId;

  const CreateCrewParams({
    required this.name,
    required this.region,
    required this.description,
    required this.maxMembers,
    required this.leaderId,
  });
}

// 크루 생성 유스케이스
class CreateCrewUseCase {
  final CrewRepository _repository;

  const CreateCrewUseCase(this._repository);

  Future<CrewEntity> call(CreateCrewParams params) => _repository.createCrew(
        name: params.name,
        region: params.region,
        description: params.description,
        maxMembers: params.maxMembers,
        leaderId: params.leaderId,
      );
}
