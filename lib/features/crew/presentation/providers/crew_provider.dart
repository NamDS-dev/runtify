import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/crew_firestore_datasource.dart';
import '../../data/repositories/crew_repository_impl.dart';
import '../../domain/entities/crew_entity.dart';
import '../../domain/entities/join_request_entity.dart';
import '../../domain/repositories/crew_repository.dart';
import '../../domain/usecases/create_crew_usecase.dart';
import '../../domain/usecases/get_crews_usecase.dart';
import '../../domain/usecases/join_crew_usecase.dart';
import '../../domain/usecases/leave_crew_usecase.dart';

// ── 데이터소스 Provider ────────────────────────────────────────────────────
final crewDataSourceProvider = Provider<CrewFirestoreDataSource>((ref) {
  return CrewFirestoreDataSource(firestore: FirebaseFirestore.instance);
});

// ── Repository Provider (Clean Architecture 중간 레이어) ──────────────────
final crewRepositoryProvider = Provider<CrewRepository>((ref) {
  return CrewRepositoryImpl(dataSource: ref.read(crewDataSourceProvider));
});

// ── UseCase Providers ────────────────────────────────────────────────────
final getCrewsUseCaseProvider = Provider<GetCrewsUseCase>((ref) {
  return GetCrewsUseCase(ref.read(crewRepositoryProvider));
});

final createCrewUseCaseProvider = Provider<CreateCrewUseCase>((ref) {
  return CreateCrewUseCase(ref.read(crewRepositoryProvider));
});

final joinCrewUseCaseProvider = Provider<JoinCrewUseCase>((ref) {
  return JoinCrewUseCase(ref.read(crewRepositoryProvider));
});

final leaveCrewUseCaseProvider = Provider<LeaveCrewUseCase>((ref) {
  return LeaveCrewUseCase(ref.read(crewRepositoryProvider));
});

// ── 전체 크루 목록 조회 ───────────────────────────────────────────────────
// UseCase를 통해 조회 (Clean Architecture 준수)
final crewsProvider = FutureProvider<List<CrewEntity>>((ref) async {
  final useCase = ref.read(getCrewsUseCaseProvider);
  return useCase();
});

// ── 크루 단건 조회 (crewId로) ─────────────────────────────────────────────
final crewDetailProvider =
    FutureProvider.family<CrewEntity?, String>((ref, crewId) async {
  final dataSource = ref.read(crewDataSourceProvider);
  return dataSource.getCrewById(crewId);
});

// ── 크루 멤버 정보 조회 ───────────────────────────────────────────────────
final crewMembersProvider = FutureProvider.family<List<CrewMemberInfo>,
    List<String>>((ref, memberIds) async {
  final dataSource = ref.read(crewDataSourceProvider);
  return dataSource.getCrewMembersInfo(memberIds);
});

// ── 크루 액션 상태 (가입/탈퇴/생성 로딩 표시) ─────────────────────────────
class CrewActionsNotifier extends StateNotifier<AsyncValue<void>> {
  final CreateCrewUseCase _createCrewUseCase;
  final JoinCrewUseCase _joinCrewUseCase;
  final LeaveCrewUseCase _leaveCrewUseCase;
  final Ref _ref;

  CrewActionsNotifier({
    required CreateCrewUseCase createCrewUseCase,
    required JoinCrewUseCase joinCrewUseCase,
    required LeaveCrewUseCase leaveCrewUseCase,
    required Ref ref,
  })  : _createCrewUseCase = createCrewUseCase,
        _joinCrewUseCase = joinCrewUseCase,
        _leaveCrewUseCase = leaveCrewUseCase,
        _ref = ref,
        super(const AsyncValue.data(null));

  // 크루 생성
  Future<CrewEntity?> createCrew({
    required String name,
    required String region,
    required String description,
    required int maxMembers,
    required String leaderId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final crew = await _createCrewUseCase(CreateCrewParams(
        name: name,
        region: region,
        description: description,
        maxMembers: maxMembers,
        leaderId: leaderId,
      ));
      state = const AsyncValue.data(null);
      // 크루 목록 갱신
      _ref.invalidate(crewsProvider);
      return crew;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  // 크루 가입
  Future<bool> joinCrew({
    required String crewId,
    required String userId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _joinCrewUseCase(JoinCrewParams(crewId: crewId, userId: userId));
      state = const AsyncValue.data(null);
      // 크루 목록, 상세 갱신
      _ref.invalidate(crewsProvider);
      _ref.invalidate(crewDetailProvider(crewId));
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // 크루 탈퇴
  Future<bool> leaveCrew({
    required String crewId,
    required String userId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _leaveCrewUseCase(LeaveCrewParams(crewId: crewId, userId: userId));
      state = const AsyncValue.data(null);
      // 크루 목록, 상세 갱신
      _ref.invalidate(crewsProvider);
      _ref.invalidate(crewDetailProvider(crewId));
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // 크루 정보 수정 (리더 전용)
  Future<bool> updateCrew({
    required String crewId,
    required String name,
    required String region,
    required String description,
    required int maxMembers,
  }) async {
    state = const AsyncValue.loading();
    try {
      final datasource = _ref.read(crewDataSourceProvider);
      await datasource.updateCrew(
        crewId: crewId,
        name: name,
        region: region,
        description: description,
        maxMembers: maxMembers,
      );
      state = const AsyncValue.data(null);
      _ref.invalidate(crewsProvider);
      _ref.invalidate(crewDetailProvider(crewId));
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // 멤버 강제 퇴출 (리더 전용)
  Future<bool> kickMember({
    required String crewId,
    required String memberId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final datasource = _ref.read(crewDataSourceProvider);
      await datasource.kickMember(crewId: crewId, memberId: memberId);
      state = const AsyncValue.data(null);
      _ref.invalidate(crewDetailProvider(crewId));
      _ref.invalidate(crewMembersProvider);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final crewActionsProvider =
    StateNotifierProvider<CrewActionsNotifier, AsyncValue<void>>((ref) {
  return CrewActionsNotifier(
    createCrewUseCase: ref.read(createCrewUseCaseProvider),
    joinCrewUseCase: ref.read(joinCrewUseCaseProvider),
    leaveCrewUseCase: ref.read(leaveCrewUseCaseProvider),
    ref: ref,
  );
});

// ── 가입 신청 관련 Provider ───────────────────────────────────────────────

// 대기 중인 가입 신청 목록 (리더용, 실시간)
final pendingRequestsProvider =
    StreamProvider.family<List<JoinRequestEntity>, String>((ref, crewId) {
  final datasource = ref.read(crewDataSourceProvider);
  return datasource.watchPendingRequests(crewId);
});

// 특정 유저의 가입 신청 상태 (비멤버용)
final joinRequestStatusProvider =
    FutureProvider.family<JoinRequestEntity?, ({String crewId, String userId})>(
        (ref, params) {
  final datasource = ref.read(crewDataSourceProvider);
  return datasource.getJoinRequestStatus(
    crewId: params.crewId,
    userId: params.userId,
  );
});
