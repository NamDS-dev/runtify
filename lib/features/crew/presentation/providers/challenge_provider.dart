import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/crew_firestore_datasource.dart';
import '../../data/models/challenge_model.dart';
import '../../domain/entities/challenge_entity.dart';
import 'crew_provider.dart';

// ── 챌린지 목록 스트림 Provider ───────────────────────────────────────────
// crewId 기준으로 챌린지 실시간 구독
final challengesProvider =
    StreamProvider.family<List<ChallengeEntity>, String>((ref, crewId) {
  final dataSource = ref.read(crewDataSourceProvider);
  return dataSource.getChallenges(crewId);
});

// ── 챌린지 액션 상태 클래스 ───────────────────────────────────────────────
class ChallengeActionsState {
  final bool isLoading;
  final String? error;

  const ChallengeActionsState({
    this.isLoading = false,
    this.error,
  });

  ChallengeActionsState copyWith({bool? isLoading, String? error}) {
    return ChallengeActionsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── 챌린지 액션 Notifier ─────────────────────────────────────────────────
// 챌린지 생성 등 액션의 로딩/에러 상태 관리
class ChallengeActionsNotifier extends StateNotifier<ChallengeActionsState> {
  final CrewFirestoreDataSource _dataSource;
  final Ref _ref;

  ChallengeActionsNotifier({
    required CrewFirestoreDataSource dataSource,
    required Ref ref,
  })  : _dataSource = dataSource,
        _ref = ref,
        super(const ChallengeActionsState());

  // 새 챌린지 생성 (크루장만 호출 가능 — UI에서 권한 체크)
  Future<bool> createChallenge({
    required String crewId,
    required ChallengeType type,
    required double targetValue,
    required int bonusPoints,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final model = ChallengeModel(
        id: '', // Firestore에서 자동 생성
        type: type,
        targetValue: targetValue,
        currentValue: 0,
        startDate: startDate,
        endDate: endDate,
        bonusPoints: bonusPoints,
        status: ChallengeStatus.active,
        participantCount: 0,
      );
      await _dataSource.createChallenge(crewId, model);

      // 챌린지 목록 캐시 무효화
      _ref.invalidate(challengesProvider(crewId));

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // 만료 챌린지 일괄 처리 (화면 진입 시 호출)
  Future<void> processExpiredChallenges(String crewId) async {
    try {
      await _dataSource.completeChallenges(crewId);
      _ref.invalidate(challengesProvider(crewId));
    } catch (_) {
      // 조용히 실패 — 배경 처리라 사용자에게 에러 표시 안 함
    }
  }
}

// ── Provider 등록 ─────────────────────────────────────────────────────────
final challengeActionsProvider =
    StateNotifierProvider<ChallengeActionsNotifier, ChallengeActionsState>(
        (ref) {
  return ChallengeActionsNotifier(
    dataSource: ref.read(crewDataSourceProvider),
    ref: ref,
  );
});
