import '../entities/crew_entity.dart';
import '../repositories/crew_repository.dart';

// 크루 목록 조회 유스케이스
class GetCrewsUseCase {
  final CrewRepository _repository;

  const GetCrewsUseCase(this._repository);

  Future<List<CrewEntity>> call() => _repository.getCrews();
}
