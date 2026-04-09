import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../crew/presentation/providers/crew_provider.dart';
import '../../data/datasources/health_connect_datasource.dart';
import '../providers/running_provider.dart';
import '../widgets/stats_overview_widget.dart';

// 홈 허브 화면 — Runtify 전체 진입점
// 러닝 기록 목록은 러닝 섹션 탭으로 이동됨
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (user) {
        // 로그인 안 된 경우 로그인 페이지로
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/login');
          });
          return const Scaffold(body: SizedBox());
        }

        final runsAsync = ref.watch(recentRunsProvider(user.id));

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'RUNTIFY',
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_outline),
                onPressed: () => context.push('/profile'),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(recentRunsProvider(user.id)),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 인사말 + 스트릭 배지
                  _GreetingSection(name: user.name, streak: user.streak),
                  const SizedBox(height: 12),

                  // 레벨 진행바
                  _LevelProgressBar(
                    level: user.level,
                    experience: user.experience,
                  ),
                  const SizedBox(height: 20),

                  // 러닝 시작하기 메인 CTA 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/running'),
                      icon: const Icon(Icons.play_arrow_rounded, size: 28),
                      label: const Text(
                        '러닝 시작하기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 크루 + 지역 랭킹 미니 카드 2열
                  Row(
                    children: [
                      Expanded(child: _CrewMiniCard(crewId: user.crewId)),
                      const SizedBox(width: 12),
                      Expanded(child: _RegionMiniCard(userId: user.id)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 리워드 포인트 배너
                  _RewardBanner(points: user.points),
                  const SizedBox(height: 12),

                  // 워치 동기화 카드 (모바일 + Health Connect 권한 있을 때만)
                  if (!kIsWeb) _WatchSyncCard(userId: user.id),

                  // 이번 달 통계 요약 카드
                  runsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('$e'),
                    data: (sessions) => StatsOverviewWidget(sessions: sessions),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── 인사말 + 스트릭 섹션 ───────────────────────────────────────────────────
class _GreetingSection extends StatelessWidget {
  final String name;
  final int streak;

  const _GreetingSection({required this.name, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            '안녕하세요, $name님!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        if (streak > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  '$streak일',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── 레벨 진행바 ──────────────────────────────────────────────────────────
// 레벨업 기준: 100 XP = 1레벨 (saveSession 로직과 동일)
class _LevelProgressBar extends StatelessWidget {
  final int level;
  final int experience;

  const _LevelProgressBar({required this.level, required this.experience});

  @override
  Widget build(BuildContext context) {
    // 현재 레벨 내 경험치 (0~99 범위)
    final currentLevelExp = experience - (level - 1) * 100;
    final progress = (currentLevelExp / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lv.$level',
              style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              '$currentLevelExp / 100 XP  →  Lv.${level + 1}',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: context.colors.surface,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
          ),
        ),
      ],
    );
  }
}

// ── 크루 미니 카드 ────────────────────────────────────────────────────────
// crewId가 있으면 Firestore에서 실제 크루명 조회해서 표시
class _CrewMiniCard extends ConsumerWidget {
  final String? crewId;

  const _CrewMiniCard({required this.crewId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCrew = crewId != null && crewId!.isNotEmpty;

    // 크루에 가입된 경우 크루 상세 데이터 조회
    final crewAsync = hasCrew
        ? ref.watch(crewDetailProvider(crewId!))
        : null;

    // 크루명 + 이번 달 포인트 결정 (조회 완료 시 실제 데이터 표시)
    final crewName = crewAsync?.whenOrNull(data: (c) => c?.name) ??
        (hasCrew ? '활동 중' : '미가입');
    final monthlyPoints = crewAsync?.whenOrNull(data: (c) => c?.monthlyPoints);

    return GestureDetector(
      onTap: () => context.go('/crew'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.group_outlined,
                  size: 14,
                  color: AppTheme.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '내 크루',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              crewName,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // 크루 가입 시 이번 달 포인트 표시
            if (hasCrew && monthlyPoints != null)
              Text(
                '이번 달 ${monthlyPoints}P',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Text(
                hasCrew ? '크루 탭 보기 →' : '크루 참가하기 →',
                style: const TextStyle(
                  color: AppTheme.secondary,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 지역 랭킹 미니 카드 ──────────────────────────────────────────────────
// 최근 러닝 기록에서 지역 정보를 가져와 표시
// Phase 3에서 실제 순위 연동 예정
class _RegionMiniCard extends ConsumerWidget {
  final String userId;

  const _RegionMiniCard({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(recentRunsProvider(userId));

    // 최근 러닝에서 지역 정보 추출
    final region = runsAsync.whenOrNull(
      data: (sessions) {
        final recent = sessions.where((s) => s.region.isNotEmpty).firstOrNull;
        return recent?.region;
      },
    );

    return GestureDetector(
      onTap: () => context.go('/ranking'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppTheme.secondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '내 지역',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              // 지역 정보가 있으면 표시, 없으면 "미설정"
              region ?? '미설정',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            const Text(
              '랭킹 탭 보기 →',
              style: TextStyle(
                color: AppTheme.secondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 리워드 포인트 배너 ────────────────────────────────────────────────────
class _RewardBanner extends StatelessWidget {
  final int points;

  const _RewardBanner({required this.points});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/reward'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('💰', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '리워드 포인트',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${_formatPoints(points)}P 보유',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Row(
              children: [
                Text(
                  '리워드 보기',
                  style: TextStyle(color: AppTheme.accent, fontSize: 13),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.accent,
                  size: 12,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPoints(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return k == k.roundToDouble()
          ? '${k.toInt()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return '$n';
  }
}

// ── 워치 동기화 카드 (Health Connect) ──────────────────────────────────
class _WatchSyncCard extends ConsumerStatefulWidget {
  final String userId;
  const _WatchSyncCard({required this.userId});

  @override
  ConsumerState<_WatchSyncCard> createState() => _WatchSyncCardState();
}

class _WatchSyncCardState extends ConsumerState<_WatchSyncCard> {
  bool _hasPermission = false;
  bool _isLoading = true;
  bool _isSyncing = false;
  List<dynamic> _watchSessions = [];

  @override
  void initState() {
    super.initState();
    _checkAndLoad();
  }

  Future<void> _checkAndLoad() async {
    try {
      final hc = HealthConnectDataSource();
      _hasPermission = await hc.hasPermissions();
      if (_hasPermission) {
        final sessions = await hc.getRecentSessions(widget.userId);
        _watchSessions = sessions.take(2).toList(); // 최근 2건만 미리보기
      }
    } catch (_) {
      _hasPermission = false;
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // 전체 기록 가져오기 (Firestore에 저장)
  Future<void> _syncAll() async {
    setState(() => _isSyncing = true);
    try {
      final hc = HealthConnectDataSource();
      final sessions = await hc.getRecentSessions(widget.userId);
      final dataSource = ref.read(runningDataSourceProvider);

      int synced = 0;
      for (final session in sessions) {
        try {
          await dataSource.saveSession(session);
          synced++;
        } catch (_) {
          // 이미 저장된 세션은 스킵 (중복 방지)
        }
      }

      if (mounted) {
        // 캐시 무효화
        ref.invalidate(recentRunsProvider(widget.userId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$synced건의 기록을 동기화했습니다!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '동기화에 실패했습니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFFF3333),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
    }
    if (mounted) setState(() => _isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중이거나 권한 없으면 숨김
    if (_isLoading || !_hasPermission) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '⌚ 워치 동기화',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  if (_watchSessions.isNotEmpty)
                    Text(
                      '${_watchSessions.length}건 새 기록',
                      style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 기록 미리보기 (최대 2건)
              if (_watchSessions.isEmpty)
                Text(
                  '동기화된 워치 기록이 없습니다',
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                )
              else
                ..._watchSessions.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '🏃 ${s.distanceKm.toStringAsFixed(1)}km · ${_formatDuration(s.durationSeconds)} · ${s.avgHeartRate.round()}bpm',
                            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                          ),
                          Text(
                            _formatDate(s.startTime),
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                          ),
                        ],
                      ),
                    )),

              const SizedBox(height: 8),

              // 전체 가져오기 버튼
              GestureDetector(
                onTap: _isSyncing ? null : _syncAll,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: _isSyncing
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                          )
                        : const Text(
                            '전체 기록 가져오기 →',
                            style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return '오늘 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return '어제 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
