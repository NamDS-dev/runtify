import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/crew_entity.dart';
import '../providers/crew_provider.dart';

// 크루 목록 화면 — Firebase 실데이터 연동
class CrewPage extends ConsumerWidget {
  const CrewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final crewsAsync = ref.watch(crewsProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: ErrorView(error: e)),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/login');
          });
          return const Scaffold(body: SizedBox());
        }

        // 내가 가입한 크루 여부
        final myCrewId = user.crewId;
        final hasCrew = myCrewId != null && myCrewId.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('크루'),
          ),
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(crewsProvider),
            child: crewsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(
                error: e,
                onRetry: () => ref.invalidate(crewsProvider),
              ),
              data: (crews) {
                // 내 크루 찾기
                final myCrew = hasCrew
                    ? crews.where((c) => c.id == myCrewId).firstOrNull
                    : null;

                // 가입 가능한 크루 (내 크루 제외)
                final otherCrews = crews
                    .where((c) => c.id != myCrewId)
                    .toList();

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 내 크루 섹션 ───────────────────────────────────
                      Text(
                        '내 크루',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (hasCrew && myCrew != null)
                        // 가입된 크루 카드
                        _MyCrewCard(crew: myCrew, userId: user.id, ref: ref)
                      else
                        // 크루 없음 상태
                        _NoCrewBanner(),

                      const SizedBox(height: 24),

                      // ── 크루 찾기 섹션 ────────────────────────────────
                      Text(
                        '크루 찾기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (otherCrews.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              '아직 크루가 없어요. 첫 번째 크루를 만들어보세요!',
                              style: TextStyle(color: context.colors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        Column(
                          children: otherCrews
                              .map((crew) => _CrewCard(
                                    crew: crew,
                                    canJoin: !hasCrew, // 이미 크루 있으면 가입 불가
                                    userId: user.id,
                                    ref: ref,
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          // 우하단 FAB: 크루 만들기 (크루 없을 때만)
          floatingActionButton: !hasCrew
              ? FloatingActionButton.extended(
                  onPressed: () => context.push('/crew/create'),
                  backgroundColor: AppTheme.primary,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    '크루 만들기',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
              : null,
        );
      },
    );
  }
}

// ── 내 크루 카드 (가입 상태) ───────────────────────────────────────────────
class _MyCrewCard extends StatelessWidget {
  final CrewEntity crew;
  final String userId;
  final WidgetRef ref;

  const _MyCrewCard({
    required this.crew,
    required this.userId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/crew/detail', extra: crew),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      crew.name,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${crew.crewPoints}P',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: context.colors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  crew.region,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.group_outlined,
                    size: 14, color: context.colors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${crew.memberCount}/${crew.maxMembers}명',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '상세 보기 →',
              style: TextStyle(color: AppTheme.primary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 크루 없음 배너 ────────────────────────────────────────────────────────
class _NoCrewBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.group_add, color: AppTheme.secondary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '아직 크루가 없어요',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '크루에 가입하거나 직접 만들어보세요!',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 크루 목록 카드 ────────────────────────────────────────────────────────
class _CrewCard extends StatelessWidget {
  final CrewEntity crew;
  final bool canJoin; // 가입 가능 여부 (이미 크루 있으면 false)
  final String userId;
  final WidgetRef ref;

  const _CrewCard({
    required this.crew,
    required this.canJoin,
    required this.userId,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = crew.memberCount >= crew.maxMembers;

    return GestureDetector(
      onTap: () => context.push('/crew/detail', extra: crew),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 크루명 + 포인트
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  crew.name,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${crew.crewPoints}P',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 지역 + 멤버수
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: context.colors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  crew.region,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.group_outlined,
                    size: 14, color: context.colors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${crew.memberCount}/${crew.maxMembers}명',
                  style: TextStyle(
                    color: isFull ? Colors.red.shade300 : context.colors.textSecondary,
                    fontSize: 12,
                    fontWeight: isFull ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),

            // 소개글
            if (crew.description != null && crew.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                crew.description!,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            // 가입하기 버튼
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: (canJoin && !isFull)
                    ? () => _joinCrew(context)
                    : null,
                child: Text(
                  isFull
                      ? '인원 마감'
                      : canJoin
                          ? '가입하기'
                          : '상세 보기',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinCrew(BuildContext context) async {
    // 가입 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(
          '${crew.name} 가입',
          style: TextStyle(color: context.colors.textPrimary),
        ),
        content: Text(
          '이 크루에 가입하시겠습니까?',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소', style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('가입', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success = await ref.read(crewActionsProvider.notifier).joinCrew(
          crewId: crew.id,
          userId: userId,
        );

    if (!context.mounted) return;

    if (success) {
      // 유저 정보 갱신 (crewId 업데이트 반영)
      await ref.read(authProvider.notifier).refreshUser();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${crew.name}에 가입했어요!'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } else {
      final error = ref.read(crewActionsProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('가입 실패: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
