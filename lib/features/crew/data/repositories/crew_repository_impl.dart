import '../../domain/entities/crew_entity.dart';
import '../../domain/repositories/crew_repository.dart';
import '../datasources/crew_firestore_datasource.dart';

// 크루 Repository 구현체 — Firestore DataSource를 감싸는 어댑터
class CrewRepositoryImpl implements CrewRepository {
  final CrewFirestoreDataSource _dataSource;

  const CrewRepositoryImpl({required CrewFirestoreDataSource dataSource})
      : _dataSource = dataSource;

  @override
  Future<List<CrewEntity>> getCrews() => _dataSource.getCrews();

  @override
  Future<CrewEntity?> getCrewById(String crewId) =>
      _dataSource.getCrewById(crewId);

  @override
  Future<List<CrewMemberInfo>> getCrewMembersInfo(List<String> memberIds) =>
      _dataSource.getCrewMembersInfo(memberIds);

  @override
  Future<CrewEntity> createCrew({
    required String name,
    required String region,
    required String description,
    required int maxMembers,
    required String leaderId,
  }) =>
      _dataSource.createCrew(
        name: name,
        region: region,
        description: description,
        maxMembers: maxMembers,
        leaderId: leaderId,
      );

  @override
  Future<void> joinCrew({
    required String crewId,
    required String userId,
  }) =>
      _dataSource.joinCrew(crewId: crewId, userId: userId);

  @override
  Future<void> leaveCrew({
    required String crewId,
    required String userId,
  }) =>
      _dataSource.leaveCrew(crewId: crewId, userId: userId);
}
