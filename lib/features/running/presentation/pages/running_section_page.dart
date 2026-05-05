import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/running_firestore_datasource.dart';
import '../../data/models/running_session_model.dart';
import '../providers/running_provider.dart';
import '../providers/goal_provider.dart';
import '../widgets/running_session_card.dart';
import '../widgets/stats_overview_widget.dart';
import '../../domain/entities/goal_entity.dart';
import '../../domain/entities/running_session_entity.dart';
import 'stats_page.dart';

// 러닝 섹션 화면 — 러닝 전용 허브 (기록/캘린더/목표 내부 탭)
class RunningSectionPage extends ConsumerWidget {
  const RunningSectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

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

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('러닝'),
              bottom: TabBar(
                labelColor: AppTheme.primary,
                unselectedLabelColor: context.colors.textSecondary,
                indicatorColor: AppTheme.primary,
                tabs: const [
                  Tab(text: '기록'),
                  Tab(text: '캘린더'),
                  Tab(text: '통계'),
                  Tab(text: '목표'),
                ],
              ),
            ),
            body: TabBarView(
              // 탭 간 수평 스와이프 비활성화 → Dismissible 스와이프 삭제와 충돌 방지
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // 기록 탭: 러닝 시작 버튼 + Health Connect + 최근 러닝 목록
                _HistoryTab(userId: user.id),
                // 캘린더 탭: Phase 3.5 구현 완료
                _CalendarTab(userId: user.id),
                // 통계 탭: 주간/월간 합계 + 막대 그래프
                StatsPage(userId: user.id),
                // 목표 탭: 추후 구현
                const _GoalsTab(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 기록 탭 ──────────────────────────────────────────────────────────────
class _HistoryTab extends ConsumerStatefulWidget {
  final String userId;

  const _HistoryTab({required this.userId});

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  bool _isSyncing = false;
  bool _isSeeding = false;

  // 2월 테스트 데이터 Firestore에 추가 (디버그 전용)
  Future<void> _seedFebruaryData() async {
    setState(() => _isSeeding = true);
    try {
      final seeds = [
        RunningSessionModel(
          id: '${widget.userId}_seed_feb_01',
          userId: widget.userId,
          startTime: DateTime(2026, 2, 5, 7, 30),
          endTime: DateTime(2026, 2, 5, 8, 15),
          distanceKm: 5.2,
          durationSeconds: 2700,
          avgPaceMinPerKm: 5.77,
          avgHeartRate: 148.0,
          calories: 305.0,
          pointsEarned: 52,
          region: '서울시 강남구',
        ),
        RunningSessionModel(
          id: '${widget.userId}_seed_feb_02',
          userId: widget.userId,
          startTime: DateTime(2026, 2, 10, 7, 0),
          endTime: DateTime(2026, 2, 10, 8, 0),
          distanceKm: 7.8,
          durationSeconds: 3600,
          avgPaceMinPerKm: 7.69,
          avgHeartRate: 155.0,
          calories: 458.0,
          pointsEarned: 78,
          region: '서울시 강남구',
        ),
        RunningSessionModel(
          id: '${widget.userId}_seed_feb_03',
          userId: widget.userId,
          startTime: DateTime(2026, 2, 11, 18, 0),
          endTime: DateTime(2026, 2, 11, 18, 45),
          distanceKm: 4.5,
          durationSeconds: 2700,
          avgPaceMinPerKm: 6.0,
          avgHeartRate: 142.0,
          calories: 264.0,
          pointsEarned: 45,
          region: '서울시 강남구',
        ),
        RunningSessionModel(
          id: '${widget.userId}_seed_feb_04',
          userId: widget.userId,
          startTime: DateTime(2026, 2, 12, 7, 30),
          endTime: DateTime(2026, 2, 12, 8, 20),
          distanceKm: 6.1,
          durationSeconds: 3000,
          avgPaceMinPerKm: 8.19,
          avgHeartRate: 151.0,
          calories: 358.0,
          pointsEarned: 61,
          region: '서울시 강남구',
        ),
        RunningSessionModel(
          id: '${widget.userId}_seed_feb_05',
          userId: widget.userId,
          startTime: DateTime(2026, 2, 20, 7, 0),
          endTime: DateTime(2026, 2, 20, 8, 30),
          distanceKm: 10.0,
          durationSeconds: 5400,
          avgPaceMinPerKm: 9.0,
          avgHeartRate: 162.0,
          calories: 587.0,
          pointsEarned: 100,
          region: '서울시 강남구',
        ),
      ];
      // 테스트 데이터는 트랜잭션 없이 running_sessions에 직접 쓰기
      final firestore = FirebaseFirestore.instance;
      for (final s in seeds) {
        await firestore
            .collection('running_sessions')
            .doc(s.id)
            .set(s.toFirestore());
      }
      ref.invalidate(recentRunsProvider(widget.userId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('2월 테스트 데이터 5개 추가 완료!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  // Health Connect → Firestore 동기화
  Future<void> _syncFromHealthConnect() async {
    setState(() => _isSyncing = true);

    try {
      final healthDs = ref.read(healthConnectDataSourceProvider);
      final sessions = await healthDs.getRecentSessions(widget.userId);

      if (sessions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('가져올 새 러닝 기록이 없어요'),
              backgroundColor: context.colors.surface,
            ),
          );
        }
        return;
      }

      final firestoreDs = RunningFirestoreDataSource(
        firestore: FirebaseFirestore.instance,
      );
      for (final session in sessions) {
        await firestoreDs.saveSession(session);
      }

      ref.invalidate(recentRunsProvider(widget.userId));
      await ref.read(authProvider.notifier).refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${sessions.length}개의 러닝 기록을 동기화했어요'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('동기화 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final runsAsync = ref.watch(recentRunsProvider(widget.userId));
    // 웹이 아닐 때만 Health Connect 권한 확인
    final permissionState =
        kIsWeb ? const AsyncValue.data(true) : ref.watch(healthPermissionProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(recentRunsProvider(widget.userId)),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 디버그 전용: 2월 테스트 데이터 추가 버튼
            if (kDebugMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSeeding ? null : _seedFebruaryData,
                    icon: _isSeeding
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.science_outlined, size: 16),
                    label: Text(_isSeeding ? '추가 중...' : '[DEV] 2월 테스트 데이터 추가'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),

            // 러닝 시작 CTA 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/running'),
                icon: const Icon(Icons.play_arrow_rounded, size: 24),
                label: const Text(
                  '러닝 시작하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Health Connect 권한 배너 (Android + 권한 없을 때만)
            if (!kIsWeb)
              permissionState.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (hasPermission) => hasPermission
                    ? const SizedBox.shrink()
                    : _HealthConnectBanner(
                        onTap: () => ref
                            .read(healthPermissionProvider.notifier)
                            .requestPermission(),
                      ),
              ),

            // 워치 동기화 버튼 (Android + 권한 있을 때)
            if (!kIsWeb)
              permissionState.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => const SizedBox.shrink(),
                data: (hasPermission) => hasPermission
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isSyncing ? null : _syncFromHealthConnect,
                            icon: _isSyncing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primary,
                                    ),
                                  )
                                : const Icon(
                                    Icons.watch_rounded,
                                    color: AppTheme.primary,
                                  ),
                            label: Text(
                              _isSyncing ? '동기화 중...' : '워치 기록 가져오기',
                              style: const TextStyle(color: AppTheme.primary),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

            // 이번 달 통계 요약
            runsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorView(error: e, inline: true),
              data: (sessions) => StatsOverviewWidget(sessions: sessions),
            ),
            const SizedBox(height: 16),

            // 최근 러닝 기록 목록
            Text(
              '최근 러닝 기록',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            runsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => ErrorView(error: e, inline: true),
              data: (sessions) => sessions.isEmpty
                  ? Text(
                      '아직 러닝 기록이 없어요. 첫 러닝을 시작해보세요!',
                      style: TextStyle(color: context.colors.textSecondary),
                    )
                  : Column(
                      children: sessions
                          .map((s) => RunningSessionCard(session: s))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Health Connect 권한 요청 배너
class _HealthConnectBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _HealthConnectBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.watch, color: AppTheme.accent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '갤럭시 워치 연동하기',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Health Connect 권한을 허용하면\n워치 러닝 기록을 가져올 수 있어요',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.accent, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── 캘린더 탭 ─────────────────────────────────────────────────────────────
class _CalendarTab extends ConsumerStatefulWidget {
  final String userId;

  const _CalendarTab({required this.userId});

  @override
  ConsumerState<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<_CalendarTab> {
  // PageView 총 페이지 수 (앞뒤 100개월 = 200개월)
  static const int _totalPages = 200;
  static const int _initialPage = 100;

  late final PageController _pageController;
  // 선택된 날짜 (탭하면 해당 날짜 기록 표시)
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 페이지 인덱스 → 해당 월의 DateTime 반환
  DateTime _monthFromPage(int page) {
    final now = DateTime.now();
    // 기준월(현재 월)에서 offset만큼 앞/뒤로 이동
    final offset = page - _initialPage;
    return DateTime(now.year, now.month + offset);
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: _totalPages,
      onPageChanged: (_) {
        setState(() {
          _selectedDate = null; // 월 이동 시 날짜 선택 초기화
        });
      },
      itemBuilder: (context, page) {
        final month = _monthFromPage(page);
        return _CalendarMonthView(
          userId: widget.userId,
          month: month,
          selectedDate: _selectedDate,
          onDateSelected: (date) => setState(() => _selectedDate = date),
        );
      },
    );
  }
}

// ── 한 달 캘린더 뷰 ────────────────────────────────────────────────────────
class _CalendarMonthView extends ConsumerWidget {
  final String userId;
  final DateTime month;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _CalendarMonthView({
    required this.userId,
    required this.month,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(monthlySessionsProvider(
      (userId: userId, year: month.year, month: month.month),
    ));

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e),
      data: (sessions) {
        // 이 달에 러닝한 날짜 집합 (day만 추출)
        final runDays = sessions
            .map((s) => s.startTime.day)
            .toSet();

        // 선택된 날짜의 러닝 기록
        final selectedSessions = selectedDate != null
            ? sessions
                .where((s) => s.startTime.day == selectedDate!.day)
                .toList()
            : <RunningSessionEntity>[];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 월 표시 (< 2026년 3월 >)
              _MonthHeader(month: month),
              const SizedBox(height: 12),

              // 요일 헤더 + 날짜 그리드
              _CalendarGrid(
                month: month,
                runDays: runDays,
                selectedDate: selectedDate,
                onDateSelected: onDateSelected,
              ),
              const SizedBox(height: 16),

              // 이번 달 요약 카드
              _MonthlySummaryCard(sessions: sessions, runDays: runDays),
              const SizedBox(height: 16),

              // 선택된 날짜 기록 목록
              if (selectedDate != null) ...[
                Text(
                  '${selectedDate!.month}월 ${selectedDate!.day}일 기록',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                if (selectedSessions.isEmpty)
                  Text(
                    '이 날은 러닝 기록이 없어요',
                    style: TextStyle(color: context.colors.textSecondary),
                  )
                else
                  Column(
                    children: selectedSessions
                        .map((s) => RunningSessionCard(session: s))
                        .toList(),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── 월 헤더 (< 2026년 3월 >) ──────────────────────────────────────────────
class _MonthHeader extends StatelessWidget {
  final DateTime month;
  const _MonthHeader({required this.month});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${month.year}년 ${month.month}월',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── 캘린더 그리드 ──────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final Set<int> runDays;   // 러닝한 날짜(day) 집합
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

  const _CalendarGrid({
    required this.month,
    required this.runDays,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    // 이 달 1일의 요일 (1=월, 7=일)
    final firstDay = DateTime(month.year, month.month, 1);
    // 앞에 채울 빈 칸 수 (월요일 시작 기준)
    final leadingEmpty = firstDay.weekday - 1;
    // 이 달의 마지막 날
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    return Column(
      children: [
        // 요일 헤더 행
        Row(
          children: _weekdays.map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // 날짜 그리드
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.0,
          ),
          itemCount: leadingEmpty + daysInMonth,
          itemBuilder: (context, index) {
            // 앞쪽 빈 칸
            if (index < leadingEmpty) return const SizedBox();

            final day = index - leadingEmpty + 1;
            final date = DateTime(month.year, month.month, day);
            final isRunDay = runDays.contains(day);
            final isSelected = selectedDate?.day == day &&
                selectedDate?.month == month.month &&
                selectedDate?.year == month.year;
            final isToday = date.year == DateTime.now().year &&
                date.month == DateTime.now().month &&
                date.day == DateTime.now().day;

            return GestureDetector(
              onTap: () => onDateSelected(date),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 날짜 숫자 (선택 시 Primary 원형 배경)
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppTheme.primary
                          : isToday
                              ? AppTheme.primary.withValues(alpha: 0.2)
                              : Colors.transparent,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected || isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : context.colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  // 러닝한 날: Primary 점 표시
                  const SizedBox(height: 2),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRunDay ? AppTheme.primary : Colors.transparent,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── 이번 달 요약 카드 ──────────────────────────────────────────────────────
class _MonthlySummaryCard extends StatelessWidget {
  final List<RunningSessionEntity> sessions;
  final Set<int> runDays;

  const _MonthlySummaryCard({required this.sessions, required this.runDays});

  // 최장 스트릭 계산
  int _calcMaxStreak() {
    if (runDays.isEmpty) return 0;
    final sorted = List<int>.from(runDays)..sort();
    int maxStreak = 1, current = 1;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] == sorted[i - 1] + 1) {
        current++;
        if (current > maxStreak) maxStreak = current;
      } else {
        current = 1;
      }
    }
    return maxStreak;
  }

  @override
  Widget build(BuildContext context) {
    final totalDistance =
        sessions.fold(0.0, (total, s) => total + s.distanceKm);
    final maxStreak = _calcMaxStreak();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _SummaryStat(
            label: '활동일',
            value: '${runDays.length}일',
          ),
          _SummaryDivider(),
          _SummaryStat(
            label: '총 거리',
            value: '${totalDistance.toStringAsFixed(1)}km',
          ),
          _SummaryDivider(),
          _SummaryStat(
            label: '최장 스트릭',
            value: maxStreak > 0 ? '🔥 $maxStreak일' : '-',
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: context.colors.textSecondary.withValues(alpha: 0.2),
    );
  }
}

// ── 목표 탭 ──────────────────────────────────────────────────────────────
class _GoalsTab extends ConsumerWidget {
  const _GoalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 현재 로그인한 유저 ID 가져오기
    final authState = ref.watch(authProvider);

    return authState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('인증 오류: $e')),
      data: (user) {
        if (user == null) {
          return const Center(child: Text('로그인이 필요합니다'));
        }
        return _GoalsContent(userId: user.id);
      },
    );
  }
}

// 목표 탭 본문 — 목표 목록 스트림 구독 및 렌더링
class _GoalsContent extends ConsumerWidget {
  final String userId;

  const _GoalsContent({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider(userId));

    return goalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          '목표를 불러오는 중 오류가 발생했어요: $e',
          style: TextStyle(color: context.colors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
      data: (goals) {
        if (goals.isEmpty) return _EmptyGoalsView(userId: userId);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // 목표 카드 목록 (스와이프 삭제)
            ...goals.map((goal) => Dismissible(
              key: ValueKey(goal.id),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_rounded, color: Colors.white, size: 24),
                    SizedBox(height: 4),
                    Text('삭제', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A1A),
                    title: const Text('목표 삭제', style: TextStyle(color: Colors.white)),
                    content: Text(
                      '${goal.type.label}를 삭제할까요?',
                      style: const TextStyle(color: Color(0xFF9E9E9E)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('취소', style: TextStyle(color: Color(0xFF9E9E9E))),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (_) {
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .collection('goals')
                    .doc(goal.id)
                    .delete();
              },
              child: _GoalCard(goal: goal, userId: userId),
            )),

            const SizedBox(height: 20),

            // + 목표 추가하기 버튼 (Figma: 카드 아래, 힌트 위)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: const Color(0xFF1A1A1A),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => _AddGoalBottomSheet(userId: userId),
                  );
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D00).withValues(alpha: 0.12),
                  side: BorderSide(
                    color: const Color(0xFFFF4D00).withValues(alpha: 0.4),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '+ 목표 추가하기',
                  style: TextStyle(
                    color: Color(0xFFFF4D00),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 스와이프 삭제 힌트 텍스트 (Figma: 버튼 아래)
            const Text(
              '← 스와이프로 목표 삭제',
              style: TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
            ),
          ],
        );
      },
    );
  }

}

// 목표가 없을 때 표시하는 안내 뷰 — Figma 기준 full-width 아웃라인 버튼
class _EmptyGoalsView extends StatelessWidget {
  final String userId;

  const _EmptyGoalsView({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              '아직 설정된 목표가 없어요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '목표를 추가하고 달리기 동기를 높여보세요!',
              style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // full-width 아웃라인 버튼 (Figma 스타일)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: const Color(0xFF1A1A1A),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => _AddGoalBottomSheet(userId: userId),
                  );
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D00).withValues(alpha: 0.12),
                  side: const BorderSide(color: Color(0xFFFF4D00), width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  '+ 목표 추가하기',
                  style: TextStyle(
                    color: Color(0xFFFF4D00),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 개별 목표 카드 위젯 — Figma 3-4 디자인 기준
class _GoalCard extends ConsumerWidget {
  final GoalEntity goal;
  final String userId;

  const _GoalCard({required this.goal, required this.userId});

  // 기간 컨텍스트 라벨 생성 (예: "📅 이번 달 목표" / "🏃 이번 주 목표")
  String get _periodLabel {
    switch (goal.type) {
      case GoalType.monthlyDistance:
        return '📅 이번 달 목표';
      case GoalType.weeklyDistance:
        return '🏃 이번 주 목표';
      case GoalType.weeklyCount:
        return '🏃 이번 주 목표';
      case GoalType.streak:
        return '🔥 연속 달리기';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardColor = goal.isCompleted
        ? const Color(0xFFFF4D00).withValues(alpha: 0.10)
        : const Color(0xFF252525);

    final progressPercent = (goal.progress * 100).toStringAsFixed(0);
    final isKm = goal.type.unit == 'km';
    final currentStr = goal.currentValue.toStringAsFixed(isKm ? 1 : 0);
    final targetStr = goal.targetValue.toStringAsFixed(isKm ? 1 : 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: goal.isCompleted
            ? Border.all(color: const Color(0xFFFF4D00).withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 행: 기간 라벨(왼쪽) + 달성 뱃지(오른쪽)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _periodLabel,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9E9E9E),
                ),
              ),
              if (goal.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D00).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '✅ 달성!',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF4D00),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // 목표 이름(왼쪽) + 현재값/목표값(오른쪽)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                goal.type.label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '$currentStr / $targetStr ${goal.type.unit}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 진행률 바
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.progress,
              backgroundColor: const Color(0xFF333333),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF4D00)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),

          // 달성률 텍스트 (Primary 색상)
          Text(
            '$progressPercent% 달성',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFF4D00),
            ),
          ),
        ],
      ),
    );
  }
}

// 목표 추가 바텀시트 위젯
class _AddGoalBottomSheet extends ConsumerStatefulWidget {
  final String userId;

  const _AddGoalBottomSheet({required this.userId});

  @override
  ConsumerState<_AddGoalBottomSheet> createState() =>
      _AddGoalBottomSheetState();
}

class _AddGoalBottomSheetState extends ConsumerState<_AddGoalBottomSheet> {
  // 선택된 목표 유형 (null이면 미선택 상태)
  GoalType? _selectedType;
  final _targetController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  // 입력값 검증 결과 (null = 통과 / String = 에러 메시지)
  String? get _validationError {
    if (_selectedType == null) return null;
    final value = double.tryParse(_targetController.text);
    if (value == null) {
      return _targetController.text.isEmpty ? null : '숫자를 입력해주세요';
    }
    return _selectedType!.validateInputValue(value);
  }

  // 저장 버튼 활성화 조건: 유형 선택 + 수치 검증 통과 + 입력 비어있지 않음
  bool get _canSave {
    if (_selectedType == null) return false;
    if (_targetController.text.isEmpty) return false;
    return _validationError == null;
  }

  // 목표 저장 처리
  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _isSaving = true);

    try {
      final addGoal = ref.read(addGoalProvider);
      final target = double.parse(_targetController.text);
      await addGoal(widget.userId, _selectedType!, target);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('목표가 추가됐어요!'),
            backgroundColor: Color(0xFFFF4D00),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // streak 제외한 설정 가능한 목표 유형 목록
    final availableTypes = [
      GoalType.weeklyDistance,
      GoalType.monthlyDistance,
      GoalType.weeklyCount,
    ];

    // 입력 placeholder — 선택된 유형에 맞게 (Figma: "목표 거리 입력 (km)")
    final hintText = _selectedType == null
        ? '목표 유형을 먼저 선택하세요'
        : _selectedType!.unit == 'km'
            ? '목표 거리 입력 (km)'
            : '목표 횟수 입력 (회)';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들 바 (Figma: w=48, h=4, #666666, centered)
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF666666),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 제목 (Figma: 18px Bold white)
          const Text(
            '목표 추가',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // 목표 유형 칩 — 가로 Row, 칩 w=104, gap=8 (Figma 기준)
          Row(
            children: availableTypes.map((type) {
              final isSelected = _selectedType == type;
              final isLast = type == availableTypes.last;
              return Padding(
                padding: EdgeInsets.only(right: isLast ? 0 : 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: Container(
                    width: 104,
                    height: 36,
                    decoration: BoxDecoration(
                      // 선택: Primary 20% fill + Primary border / 비선택: #252525
                      color: isSelected
                          ? const Color(0xFFFF4D00).withValues(alpha: 0.2)
                          : const Color(0xFF252525),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF4D00)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      // Figma: 이모지 없이 라벨만 ("월간 거리", "주간 거리", "주간 횟수")
                      type.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFFFF4D00)
                            : const Color(0xFF9E9E9E),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // 목표 수치 입력 필드 (Figma: h=52, r=12, bg #252525)
          // 높이 고정 제거 — errorText 표시 시 컨테이너가 자동으로 늘어나도록
          TextField(
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFF252525),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixText: _selectedType?.unit,
              suffixStyle: const TextStyle(color: Color(0xFF9E9E9E)),
              // 상한 초과 / 음수 등 즉시 안내
              errorText: _validationError,
              errorStyle: const TextStyle(color: Color(0xFFFF3333), fontSize: 11),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // 저장 버튼 (Figma: h=52, r=14, bg #FF4D00, "저장" 16px Bold white)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _canSave && !_isSaving ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D00),
                disabledBackgroundColor:
                    const Color(0xFFFF4D00).withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '저장',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
