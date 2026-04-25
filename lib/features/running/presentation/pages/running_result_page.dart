import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../core/auth/require_email_verified.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/running_session_model.dart';
import '../../../course/data/datasources/course_firestore_datasource.dart';
import '../../../course/domain/entities/course_entity.dart';
import '../../domain/entities/badge_entity.dart';
import '../../domain/entities/running_session_entity.dart';
import '../providers/running_provider.dart';

// 러닝 완료 결과 화면 (stopRun 후 표시)
class RunningResultPage extends ConsumerStatefulWidget {
  final RunningSessionEntity? session; // null이면 저장 실패 상태
  final bool needRegionConfirm;        // 지역 컨펌 UI 표시 여부
  final String startGu;                // 시작 구 (컨펌용)
  final String endGu;                  // 종료 구 (컨펌용)

  const RunningResultPage({
    super.key,
    required this.session,
    this.needRegionConfirm = false,
    this.startGu = '',
    this.endGu = '',
  });

  @override
  ConsumerState<RunningResultPage> createState() => _RunningResultPageState();
}

class _RunningResultPageState extends ConsumerState<RunningResultPage> {
  // 지역 컨펌 상태
  String? _confirmedGu; // 사용자가 선택한 구 (null = 미선택)
  bool _isSavingConfirm = false; // 컨펌 후 저장 중 여부
  bool _badgePopupShown = false; // 배지 팝업 표시 여부

  @override
  void initState() {
    super.initState();
    // 배지 팝업: 세션에 새 배지가 있으면 빌드 후 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showBadgePopupIfNeeded();
    });
  }

  // 새로 획득한 배지가 있으면 팝업 표시
  void _showBadgePopupIfNeeded() {
    if (_badgePopupShown) return;
    final session = widget.session;
    if (session == null || session.newBadgeIds.isEmpty) return;

    _badgePopupShown = true;

    // 첫 번째 배지만 팝업 표시 (여러 개면 순차적으로)
    for (final badgeId in session.newBadgeIds) {
      final badge = allBadges.where((b) => b.id == badgeId).firstOrNull;
      if (badge == null) continue;

      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        builder: (_) => _BadgeEarnedDialog(badge: badge),
      );
      break; // MVP: 첫 번째 배지만 팝업
    }
  }

  @override
  Widget build(BuildContext context) {
    // 저장된 세션이 없으면 간단한 완료 메시지
    if (widget.session == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              const Text(
                '러닝 완료!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '기록이 저장되지 않았습니다',
                style: TextStyle(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('홈으로'),
              ),
            ],
          ),
        ),
      );
    }

    final s = widget.session!;
    // 저장 후 갱신된 유저 정보에서 스트릭 읽기
    final user = ref.watch(authProvider).valueOrNull;
    final streak = user?.streak ?? 0;
    final multiplier = user?.streakMultiplier ?? 1.0;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ─── 헤더 ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '러닝 완료!',
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (s.region.isNotEmpty)
                        Text(
                          s.region,
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ─── 지도 (루프 경로) ──────────────────────────────────
            SizedBox(
              height: 220,
              child: _buildRouteMap(s),
            ),
            const SizedBox(height: 16),

            // ─── 스탯 섹션 ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // 거리 + 시간 (2열)
                    Row(
                      children: [
                        _ResultStatBox(
                          label: '거리',
                          value: '${s.distanceKm.toStringAsFixed(2)} km',
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 12),
                        _ResultStatBox(
                          label: '시간',
                          value: _formatTime(s.durationSeconds),
                          color: context.colors.textPrimary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 심박수 + 칼로리 (2열)
                    Row(
                      children: [
                        _ResultStatBox(
                          label: '평균 심박수',
                          value: s.avgHeartRate > 0
                              ? '${s.avgHeartRate.round()} bpm'
                              : '-- bpm',
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 12),
                        _ResultStatBox(
                          label: '칼로리',
                          value: '${s.calories.round()} kcal',
                          color: AppTheme.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 포인트 + EXP (2열)
                    Row(
                      children: [
                        _ResultStatBox(
                          label: '획득 포인트',
                          value: '+${s.pointsEarned}P',
                          color: AppTheme.accent,
                        ),
                        const SizedBox(width: 12),
                        _ResultStatBox(
                          label: '획득 EXP',
                          value: '+${s.expEarned} EXP',
                          color: AppTheme.accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ─── 지역 컨펌 카드 (needRegionConfirm == true 일 때만) ──
                    if (widget.needRegionConfirm)
                      _RegionConfirmCard(
                        startGu: widget.startGu,
                        endGu: widget.endGu,
                        selectedGu: _confirmedGu,
                        isSaving: _isSavingConfirm,
                        onSelect: _onRegionSelected,
                      ),

                    if (widget.needRegionConfirm) const SizedBox(height: 12),

                    // 스트릭 배너 (streak >= 1 일 때만 표시)
                    if (streak >= 1)
                      _StreakBanner(streak: streak, multiplier: multiplier),

                    if (streak >= 1) const SizedBox(height: 12),

                    // 케이던스 (한 줄 - 향후 구현)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: context.colors.cardColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '케이던스',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '-- spm',
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 구간 페이스 (있을 때만)
                    if (s.splitPaces.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _SplitPacesSection(splits: s.splitPaces),
                    ],

                    const SizedBox(height: 16),

                    // 코스로 저장 버튼 (경로가 있을 때만)
                    if (s.routePoints.length >= 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showSaveCourseSheet(s),
                            icon: const Icon(Icons.map_outlined, size: 18),
                            label: const Text('코스로 저장'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.secondary,
                              side: BorderSide(
                                color: AppTheme.secondary.withValues(alpha: 0.5),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // 홈으로 버튼 (컨펌 필요 시 선택 후 활성화)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canNavigateHome() ? _onHomePressed : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppTheme.primary.withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          widget.needRegionConfirm && _confirmedGu == null
                              ? '지역을 선택해주세요'
                              : '홈으로',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 홈으로 이동 가능 여부 (컨펌 필요 시 지역 선택 완료 후 저장까지 끝나야 함)
  bool _canNavigateHome() {
    if (!widget.needRegionConfirm) return true;
    return _confirmedGu != null && !_isSavingConfirm;
  }

  // 지역 선택 콜백 — 선택한 구로 rankingRegion 업데이트 후 세션 저장
  // 인증 가드: 미인증 사용자가 랭킹 기여 지역까지 확정하려고 하면 인증 다이얼로그 노출
  // (단, 메인 saveSession 은 running_page.dart 에서 이미 수행됨 — 이 메서드는 region 만 갱신)
  Future<void> _onRegionSelected(String selectedGu) async {
    if (_isSavingConfirm) return;

    // 랭킹 기여 지역 확정은 인증 필수 기능 — 미인증이면 차단
    final allowed = await requireEmailVerified(
      context,
      ref,
      contextMessage: '랭킹 기여 지역을 확정하려면',
    );
    if (!allowed || !mounted) return;

    setState(() {
      _confirmedGu = selectedGu;
      _isSavingConfirm = true;
    });

    try {
      final original = widget.session;
      if (original == null) return;

      // 선택한 구에 맞게 rankingRegion 결정
      // startGu 선택 시 geoRegion의 Si/Dong 대신 startGu 기반으로만 구 교체
      // (Si/Dong은 가능한 경우 유지, 없으면 geoRegion 값 유지)
      final isStartGu = selectedGu == widget.startGu;

      // 선택한 구로 rankingRegion 업데이트한 세션 생성
      final updatedSession = RunningSessionModel(
        id: original.id,
        userId: original.userId,
        startTime: original.startTime,
        endTime: original.endTime,
        distanceKm: original.distanceKm,
        durationSeconds: original.durationSeconds,
        avgPaceMinPerKm: original.avgPaceMinPerKm,
        avgHeartRate: original.avgHeartRate,
        calories: original.calories,
        expEarned: original.expEarned,
        pointsEarned: original.pointsEarned,
        region: original.region,
        routePoints: original.routePoints,
        splitPaces: original.splitPaces,
        regionSi: original.regionSi,
        regionGu: original.regionGu,
        regionDong: original.regionDong,
        geoRegionSi: original.geoRegionSi,
        geoRegionGu: original.geoRegionGu,
        geoRegionDong: original.geoRegionDong,
        // rankingRegion: 선택한 구 적용
        // 시작 구 선택 시 Si는 geoRegionSi 유지 (같은 시·도 내 구일 가능성 높음)
        rankingRegionSi: original.geoRegionSi,
        rankingRegionGu: selectedGu,
        // Dong: startGu 선택 시 null (동 정보 없음), endGu 선택 시 geoRegionDong 유지
        rankingRegionDong: isStartGu ? null : original.geoRegionDong,
      );

      // 저장 실행
      final user = ref.read(authProvider).valueOrNull;
      final dataSource = ref.read(runningDataSourceProvider);
      await dataSource.saveSession(updatedSession);

      if (user != null) {
        ref.invalidate(recentRunsProvider(user.id));
        await ref.read(authProvider.notifier).refreshUser();
      }
    } catch (_) {
      // 저장 실패 시 선택 초기화
      if (mounted) {
        setState(() {
          _confirmedGu = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingConfirm = false);
      }
    }
  }

  // 코스 저장 BottomSheet
  void _showSaveCourseSheet(RunningSessionEntity session) {
    final nameController = TextEditingController();
    int selectedDifficulty = 3;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1A1A1A)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 핸들바
              Center(
                child: Container(
                  width: 48, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '🗺️ 코스 저장',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '${session.distanceKm.toStringAsFixed(1)}km 경로를 코스로 저장합니다',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // 코스 이름 입력
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '코스 이름 (예: 한강 반포대교 코스)',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  filled: true,
                  fillColor: const Color(0xFF252525),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 난이도 선택 (1~5 별점)
              const Text('난이도', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) {
                  final level = i + 1;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selectedDifficulty = level),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        level <= selectedDifficulty ? '⭐' : '☆',
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('코스 이름을 입력해주세요')),
                      );
                      return;
                    }

                    // 코스 저장
                    final user = ref.read(authProvider).value;
                    final course = CourseEntity(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      creatorId: user?.id ?? '',
                      creatorName: user?.name ?? '',
                      name: name,
                      regionGu: session.rankingRegionGu ?? session.regionGu ?? '',
                      regionSi: session.rankingRegionSi ?? session.regionSi ?? '',
                      distanceKm: session.distanceKm,
                      difficulty: selectedDifficulty,
                      routePoints: session.routePoints,
                      runCount: 1,
                      createdAt: DateTime.now(),
                    );

                    await CourseFirestoreDatasource().saveCourse(course);

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('코스가 저장되었습니다!'),
                          backgroundColor: AppTheme.primary,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('저장하기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 홈으로 이동
  void _onHomePressed() {
    context.go('/home');
  }

  // 루프 경로 지도
  Widget _buildRouteMap(RunningSessionEntity s) {
    if (s.routePoints.isEmpty) {
      return Container(
        color: const Color(0xFF0F1923),
        child: const Center(
          child: Text(
            '경로 없음',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    // entity LatLngPoint → latlong2 LatLng 변환
    final points = s.routePoints
        .map((p) => ll.LatLng(p.lat, p.lng))
        .toList();

    // 경로 전체가 보이도록 중심/줌 계산
    final centerLat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final centerLng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    final center = ll.LatLng(centerLat, centerLng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(0),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none, // 결과 화면에서 지도 조작 비활성화
          ),
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.runtify.app',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                color: AppTheme.primary,
                strokeWidth: 3,
              ),
            ],
          ),
          // 시작 마커 (초록)
          MarkerLayer(
            markers: [
              Marker(
                point: points.first,
                width: 14,
                height: 14,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
              // 종료 마커 (빨강)
              Marker(
                point: points.last,
                width: 14,
                height: 14,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ─── 지역 컨펌 카드 ────────────────────────────────────────────────────────────
// needRegionConfirm == true 일 때만 표시: 시작 구 vs 종료 구 선택
class _RegionConfirmCard extends StatelessWidget {
  final String startGu;
  final String endGu;
  final String? selectedGu; // 현재 선택된 구 (null = 미선택)
  final bool isSaving;
  final void Function(String gu) onSelect;

  const _RegionConfirmCard({
    required this.startGu,
    required this.endGu,
    required this.selectedGu,
    required this.isSaving,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목
          const Row(
            children: [
              Text('📍', style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Text(
                '랭킹 기여 지역을 선택해주세요',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 시작 → 종료 구 표시
          Row(
            children: [
              Text(
                '시작: $startGu',
                style: const TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 12,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '→',
                  style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
                ),
              ),
              Text(
                '종료: $endGu',
                style: const TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 선택 버튼 2개 (저장 중이면 로딩 표시)
          isSaving
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : Row(
                  children: [
                    // 시작 구 버튼
                    Expanded(
                      child: _RegionButton(
                        label: '$startGu로 기록',
                        isSelected: selectedGu == startGu,
                        onTap: () => onSelect(startGu),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 종료 구 버튼
                    Expanded(
                      child: _RegionButton(
                        label: '$endGu로 기록',
                        isSelected: selectedGu == endGu,
                        onTap: () => onSelect(endGu),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

// 지역 선택 버튼 (선택됨: Primary #FF4D00 / 미선택: #333333)
class _RegionButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _RegionButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : const Color(0xFF333333),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
            fontSize: 13,
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// 스탯 박스 (2열 레이아웃용)
class _ResultStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ResultStatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: context.colors.cardColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 스트릭 배너 (연속 러닝 일수 + 보너스 배율 표시)
class _StreakBanner extends StatelessWidget {
  final int streak;
  final double multiplier;

  const _StreakBanner({required this.streak, required this.multiplier});

  @override
  Widget build(BuildContext context) {
    // 배율에 따라 이모지 + 색상 다르게
    final String emoji;
    final Color color;
    if (streak >= 7) {
      emoji = '🔥🔥🔥';
      color = AppTheme.primary;
    } else if (streak >= 3) {
      emoji = '🔥🔥';
      color = AppTheme.secondary;
    } else {
      emoji = '🔥';
      color = AppTheme.accent;
    }

    final bonusText = multiplier > 1.0
        ? '×${multiplier.toStringAsFixed(1)} 보너스 적용!'
        : '3일 연속 달리면 보너스 시작!';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$streak일 연속 러닝',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                bonusText,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 배지 획득 팝업 다이얼로그 (Phase 6) ─────────────────────────────────
class _BadgeEarnedDialog extends StatelessWidget {
  final BadgeDefinition badge;

  const _BadgeEarnedDialog({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 300,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🎉 새 배지 획득!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(badge.emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              badge.name,
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 240,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 구간 페이스 섹션
class _SplitPacesSection extends StatelessWidget {
  final List<SplitPace> splits;

  const _SplitPacesSection({required this.splits});

  String _paceStr(double pace) {
    if (pace <= 0) return "--'--\"";
    final min = pace.floor();
    final sec = ((pace - min) * 60).round();
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '구간별 페이스',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...splits.map(
            (split) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${split.km} km',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _paceStr(split.pace),
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
