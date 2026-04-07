import '../entities/crew_entity.dart';
import '../../data/datasources/crew_firestore_datasource.dart';

// 크루 도메인 레이어 — Repository 인터페이스
// Data 레이어(CrewRepositoryImpl)에서 구현
abstract class CrewRepository {
  // 전체 크루 목록 조회 (포인트 내림차순)
  Future<List<CrewEntity>> getCrews();

  // 크루 단건 조회
  Future<CrewEntity?> getCrewById(String crewId);

  // 크루 멤버 정보 조회 (이름 + 포인트)
  Future<List<CrewMemberInfo>> getCrewMembersInfo(List<String> memberIds);

  // 크루 생성 (생성자가 리더 + 첫 멤버)
  Future<CrewEntity> createCrew({
    required String name,
    required String region,
    required String description,
    required int maxMembers,
    required String leaderId,
  });

  // 크루 가입 (1인 1크루 제한은 datasource 레벨에서 처리)
  Future<void> joinCrew({
    required String crewId,
    required String userId,
  });

  // 크루 탈퇴 (크루장은 탈퇴 불가 — UI 레벨에서 막음)
  Future<void> leaveCrew({
    required String crewId,
    required String userId,
  });
}
