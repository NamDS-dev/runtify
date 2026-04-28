import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/challenge_entity.dart';
import '../../domain/entities/crew_entity.dart';
import '../providers/challenge_provider.dart';

// 크루 위클리 챌린지 화면
// 라우터에서 extra: CrewEntity로 전달받음
class CrewChallengePage extends ConsumerStatefulWidget {
  final CrewEntity crew;

  const CrewChallengePage({super.key, required this.crew});

  @override
  ConsumerState<CrewChallengePage> createState() => _CrewChallengePageState();
}

class _CrewChallengePageState extends ConsumerState<CrewChallengePage> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 시 만료 챌린지 자동 처리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(challengeActionsProvider.notifier)
          .processExpiredChallenges(widget.crew.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final challengesAsync = ref.watch(challengesProvider(widget.crew.id));

    return authState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: ErrorView(error: e)),
      data: (user) {
        if (user == null) return const Scaffold(body: SizedBox());

        // 리더 여부 확인 — 리더만 챌린지 생성 버튼 표시
        final isLeader = widget.crew.leaderId == user.id;

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0D0D0D),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              '위클리 챌린지',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          body: challengesAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            error: (e, _) => Center(
              child: Text(
                '챌린지 조회 실패: $e',
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            data: (challenges) {
              // active / 완료·실패 분리
              final active = challenges
                  .where((c) => c.status == ChallengeStatus.active)
                  .toList();
              final history = challenges
                  .where((c) => c.status != ChallengeStatus.active)
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── 진행 중 챌린지 ────────────────────────────────
                  if (active.isNotEmpty) ...[
                    _sectionTitle('진행 중'),
                    const SizedBox(height: 12),
                    ...active.map((c) => _ActiveChallengeCard(challenge: c)),
                    const SizedBox(height: 24),
                  ] else ...[
                    _EmptyActiveCard(isLeader: isLeader),
                    const SizedBox(height: 24),
                  ],

                  // ── 리더 전용: 새 챌린지 만들기 버튼 ─────────────
                  if (isLeader) ...[
                    _CreateChallengeButton(
                      crewId: widget.crew.id,
                      memberCount: widget.crew.memberCount,
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ── 지난 챌린지 히스토리 ─────────────────────────
                  if (history.isNotEmpty) ...[
                    _sectionTitle('지난 챌린지'),
                    const SizedBox(height: 12),
                    ...history.map((c) => _HistoryChallengeCard(challenge: c)),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }

  // 섹션 타이틀 텍스트
  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }
}

// ── 진행 중 챌린지 카드 ────────────────────────────────────────────────────
class _ActiveChallengeCard extends StatelessWidget {
  final ChallengeEntity challenge;

  const _ActiveChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final progress = challenge.progress;
    final daysLeft = challenge.daysLeft;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타입 칩 + D-day
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 챌린지 타입 칩
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  challenge.typeLabel,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // D-day 표시
              Text(
                daysLeft == 0 ? 'D-day' : 'D-$daysLeft',
                style: TextStyle(
                  color: daysLeft <= 1
                      ? Colors.red.shade400
                      : const Color(0xFF9E9E9E),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 목표값 / 현재값
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text:
                          '${_formatValue(challenge.currentValue)}${challenge.unit}',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' / ${_formatValue(challenge.targetValue)}${challenge.unit}',
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // 보너스 포인트 배지
              Row(
                children: [
                  const Text('🎁', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    '+${challenge.bonusPoints}P',
                    style: const TextStyle(
                      color: Color(0xFFFFE566),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 진행 바
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),

          const SizedBox(height: 8),

          // 진행률 % + 참여 인원
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(0)}% 달성',
                style: const TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 12,
                ),
              ),
              if (challenge.type == ChallengeType.participation ||
                  challenge.type == ChallengeType.distance)
                Text(
                  '참여 ${challenge.participantCount}명',
                  style: const TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 소수점 처리: 정수면 정수, 소수면 1자리
  String _formatValue(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

// ── 진행 중 챌린지 없을 때 빈 상태 카드 ───────────────────────────────────
class _EmptyActiveCard extends StatelessWidget {
  final bool isLeader;
  const _EmptyActiveCard({this.isLeader = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('🏃', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text(
            '진행 중인 챌린지가 없어요',
            style: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isLeader
                ? '아래 버튼으로 새 챌린지를 만들어보세요!'
                : '크루 리더가 곧 챌린지를 시작할 거예요 🔥',
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 지난 챌린지 히스토리 카드 ─────────────────────────────────────────────
class _HistoryChallengeCard extends StatelessWidget {
  final ChallengeEntity challenge;

  const _HistoryChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final isCompleted = challenge.status == ChallengeStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 결과 아이콘
          Text(
            isCompleted ? '✅' : '❌',
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),

          // 타입 + 달성값
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.typeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatValue(challenge.currentValue)} / ${_formatValue(challenge.targetValue)}${challenge.unit}',
                  style: const TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // 결과 텍스트
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isCompleted ? '달성!' : '미달성',
                style: TextStyle(
                  color: isCompleted
                      ? const Color(0xFFFFE566)
                      : const Color(0xFF9E9E9E),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isCompleted)
                Text(
                  '+${challenge.bonusPoints}P',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatValue(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}

// ── 새 챌린지 만들기 버튼 (리더 전용) ───────────────────────────────────
class _CreateChallengeButton extends StatelessWidget {
  final String crewId;
  final int memberCount;

  const _CreateChallengeButton({
    required this.crewId,
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () => _showCreateBottomSheet(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          '새 챌린지 만들기',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  void _showCreateBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateChallengeBottomSheet(
        crewId: crewId,
        memberCount: memberCount,
      ),
    );
  }
}

// ── 챌린지 생성 BottomSheet ───────────────────────────────────────────────
class _CreateChallengeBottomSheet extends ConsumerStatefulWidget {
  final String crewId;
  final int memberCount;

  const _CreateChallengeBottomSheet({
    required this.crewId,
    required this.memberCount,
  });

  @override
  ConsumerState<_CreateChallengeBottomSheet> createState() =>
      _CreateChallengeBottomSheetState();
}

class _CreateChallengeBottomSheetState
    extends ConsumerState<_CreateChallengeBottomSheet> {
  // 선택된 챌린지 타입 (기본값: 합산거리)
  ChallengeType _selectedType = ChallengeType.distance;

  // 목표값 컨트롤러
  final _targetController = TextEditingController();

  // 보너스 포인트 컨트롤러
  final _bonusController = TextEditingController(text: '50');

  @override
  void dispose() {
    _targetController.dispose();
    _bonusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionsState = ref.watch(challengeActionsProvider);
    final isLoading = actionsState.isLoading;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        // 키보드가 올라올 때 BottomSheet가 가리지 않게 패딩 추가
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들 바
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 타이틀
          const Text(
            '새 챌린지 만들기',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          // ── 챌린지 타입 선택 칩 ─────────────────────────────────
          const Text(
            '챌린지 유형',
            style: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: ChallengeType.values.map((type) {
              final isSelected = _selectedType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedType = type;
                    _targetController.clear(); // 타입 변경 시 목표값 초기화
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary
                          : const Color(0xFF252525),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.white24,
                      ),
                    ),
                    child: Text(
                      _typeLabel(type),
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ── 목표값 입력 ──────────────────────────────────────────
          Text(
            '목표값 (${_unitLabel(_selectedType)})',
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _targetController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: _hintText(_selectedType),
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF252525),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixText: _unitLabel(_selectedType),
              suffixStyle: const TextStyle(color: Color(0xFF9E9E9E)),
            ),
          ),
          const SizedBox(height: 16),

          // ── 보너스 포인트 입력 ───────────────────────────────────
          const Text(
            '달성 보너스 포인트',
            style: TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bonusController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '50',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF252525),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixText: 'P',
              suffixStyle: const TextStyle(color: Color(0xFF9E9E9E)),
            ),
          ),
          const SizedBox(height: 24),

          // ── 저장 버튼 ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : () => _createChallenge(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.5),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '챌린지 시작하기',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 챌린지 생성 처리
  Future<void> _createChallenge(BuildContext context) async {
    final targetStr = _targetController.text.trim();
    final bonusStr = _bonusController.text.trim();

    if (targetStr.isEmpty) {
      _showError(context, '목표값을 입력해주세요');
      return;
    }

    final targetValue = double.tryParse(targetStr);
    if (targetValue == null || targetValue <= 0) {
      _showError(context, '올바른 목표값을 입력해주세요');
      return;
    }

    final bonusPoints = int.tryParse(bonusStr) ?? 50;

    final now = DateTime.now();
    // 챌린지 기간: 오늘부터 7일
    final endDate = now.add(const Duration(days: 7));

    final success =
        await ref.read(challengeActionsProvider.notifier).createChallenge(
              crewId: widget.crewId,
              type: _selectedType,
              targetValue: targetValue,
              bonusPoints: bonusPoints,
              startDate: now,
              endDate: endDate,
            );

    if (!context.mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('챌린지가 시작됐어요! 크루원과 함께 달려봐요 🔥'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } else {
      final error = ref.read(challengeActionsProvider).error;
      _showError(context, '생성 실패: $error');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  // 타입별 이름 (칩 표시용)
  String _typeLabel(ChallengeType type) {
    switch (type) {
      case ChallengeType.distance:
        return '합산거리';
      case ChallengeType.participation:
        return '참여율';
      case ChallengeType.streak:
        return '연속달리기';
    }
  }

  // 단위
  String _unitLabel(ChallengeType type) {
    switch (type) {
      case ChallengeType.distance:
        return 'km';
      case ChallengeType.participation:
        return '명';
      case ChallengeType.streak:
        return '일';
    }
  }

  // 입력 힌트 텍스트
  String _hintText(ChallengeType type) {
    switch (type) {
      case ChallengeType.distance:
        return '예: 100 (크루 합산 km)';
      case ChallengeType.participation:
        return '예: 5 (최소 달려야 할 인원)';
      case ChallengeType.streak:
        return '예: 5 (연속으로 달릴 일수)';
    }
  }
}
