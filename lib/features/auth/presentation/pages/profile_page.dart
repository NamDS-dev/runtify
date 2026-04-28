import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/personal_record_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/entities/user_entity.dart';
import '../../../running/domain/entities/badge_entity.dart';
import '../../../running/presentation/providers/badge_provider.dart';
import '../providers/auth_provider.dart';

// 프로필 화면 - 유저 정보 + 레벨 시스템 + 로그아웃
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

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

        return Scaffold(
          appBar: AppBar(
            title: const Text('프로필'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/home'),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),

                // 아바타
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  user.name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),

                // 레벨 + 경험치 프로그레스바
                _LevelCard(user: user),
                const SizedBox(height: 16),

                // 통계 카드 (포인트 / 총 거리 / 경험치)
                _StatsRow(user: user),
                const SizedBox(height: 20),

                // 배지 그리드 (Phase 6)
                _BadgesSection(userId: user.id),
                const SizedBox(height: 20),

                // 개인 최고 기록 (Phase 2 — 2026-04-28)
                _PersonalRecordsSection(userId: user.id),
                const SizedBox(height: 20),

                // 홈 지역 설정 (Phase 4)
                _HomeRegionCard(user: user),
                const SizedBox(height: 16),

                // 테마 설정
                _ThemeSelector(),
                const SizedBox(height: 20),

                // 마케팅 수신 동의 토글 (정보통신망법 § 50 대비)
                _MarketingConsentToggle(user: user),
                const SizedBox(height: 20),

                // 로그아웃 버튼
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).signOut();
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      '로그아웃',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 레벨 + 경험치 프로그레스바 카드
class _LevelCard extends StatelessWidget {
  final UserEntity user;

  const _LevelCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Lv.${user.level}',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '다음 레벨까지 ${user.expToNextLevel} EXP',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: user.levelProgress,
              minHeight: 8,
              backgroundColor: context.colors.surface,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${user.experience} EXP',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// 통계 3칸
class _StatsRow extends StatelessWidget {
  final UserEntity user;

  const _StatsRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          label: '포인트',
          value: '${user.points}P',
          icon: Icons.bolt,
          color: AppTheme.accent,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: '총 거리',
          value: '${user.totalDistance.toStringAsFixed(1)}km',
          icon: Icons.directions_run,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: '경험치',
          value: '${user.experience}',
          icon: Icons.local_fire_department_rounded,
          color: AppTheme.secondary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 홈 지역 설정 카드 (Phase 4: GPS 기반 지역 설정) ──────────────
class _HomeRegionCard extends ConsumerStatefulWidget {
  final UserEntity user;

  const _HomeRegionCard({required this.user});

  @override
  ConsumerState<_HomeRegionCard> createState() => _HomeRegionCardState();
}

class _HomeRegionCardState extends ConsumerState<_HomeRegionCard> {
  bool _isLoading = false; // GPS + 역지오코딩 중 로딩 상태

  // 지역 설정 버튼 눌렀을 때: GPS 감지 → BottomSheet 확인
  Future<void> _setHomeRegion() async {
    setState(() => _isLoading = true);

    // GPS → 역지오코딩으로 현재 지역 감지
    final detectFn = ref.read(detectCurrentRegionProvider);
    final (region, error) = await detectFn();

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    // 감지 성공 → BottomSheet로 확인 요청
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RegionConfirmSheet(region: region!),
    );

    if (confirmed == true && mounted) {
      // 사용자가 "이 지역으로 설정하기" 탭
      final saveFn = ref.read(saveHomeRegionProvider);
      await saveFn(widget.user.id, region!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('홈 지역이 업데이트되었습니다!'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // authProvider에서 최신 user 데이터 읽기 (refreshUser 후 갱신됨)
    final latestUser = ref.watch(authProvider).value ?? widget.user;
    final regionLabel = latestUser.homeRegionLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (제목 + 설정 버튼)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '내 지역',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // 설정 버튼 (로딩 중이면 스피너 표시)
              _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                  : GestureDetector(
                      onTap: _setHomeRegion,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.gps_fixed, color: AppTheme.primary, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              regionLabel != null ? '지역 재설정' : '지역 설정',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 14),

          // 현재 설정된 지역 표시
          if (regionLabel != null) ...[
            Row(
              children: [
                const Icon(Icons.location_on, color: AppTheme.primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  regionLabel,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 시·도 표시 (보조 텍스트)
            if (latestUser.homeRegionSi != null && latestUser.homeRegionSi!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: Text(
                  latestUser.homeRegionSi!,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
          ] else ...[
            // 지역 미설정 상태
            Row(
              children: [
                Icon(Icons.location_off, color: context.colors.textSecondary, size: 18),
                const SizedBox(width: 6),
                Text(
                  '지역이 설정되지 않았습니다',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'GPS로 현재 위치를 감지해 랭킹에 반영됩니다',
              style: TextStyle(
                color: context.colors.textSecondary.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 배지 그리드 섹션 (Phase 6) ──────────────────────────────────
class _BadgesSection extends ConsumerWidget {
  final String userId;

  const _BadgesSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesAsync = ref.watch(earnedBadgesProvider(userId));

    // loading/error 상태에서도 그리드 표시 (모두 미획득으로)
    final earnedIds = badgesAsync.when(
      loading: () => <String>{},
      error: (_, _) => <String>{},
      data: (badges) => badges.map((b) => b.badgeId).toSet(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더: "🏅 내 배지" + 카운트
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '🏅 내 배지',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${earnedIds.length} / ${allBadges.length}',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3x2 배지 그리드
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
              ),
              itemCount: allBadges.length,
              itemBuilder: (context, index) {
                final badge = allBadges[index];
                final isEarned = earnedIds.contains(badge.id);
                return _BadgeCard(badge: badge, isEarned: isEarned);
              },
            ),
          ],
        );
  }
}

// 개별 배지 카드
class _BadgeCard extends StatelessWidget {
  final BadgeDefinition badge;
  final bool isEarned;

  const _BadgeCard({required this.badge, required this.isEarned});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isEarned ? context.colors.cardColor : context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isEarned ? badge.emoji : '🔒',
            style: TextStyle(fontSize: isEarned ? 32 : 28),
          ),
          const SizedBox(height: 8),
          Text(
            badge.name,
            style: TextStyle(
              color: isEarned ? AppTheme.primary : Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            badge.condition,
            style: TextStyle(
              color: isEarned
                  ? context.colors.textSecondary
                  : Colors.grey.shade700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 테마 설정 위젯 (라이트 / 다크 / 기기 설정) ───────────────────
class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '테마 설정',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.wb_sunny_outlined, size: 18),
                label: Text('라이트'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.nights_stay_outlined, size: 18),
                label: Text('다크'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.phone_android_outlined, size: 18),
                label: Text('기기 설정'),
              ),
            ],
            selected: {currentTheme},
            onSelectionChanged: (selected) {
              ref.read(themeProvider.notifier).setTheme(selected.first);
            },
            style: ButtonStyle(
              // 선택된 버튼: primary 색상
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.primary.withValues(alpha: 0.15);
                }
                return context.colors.surface;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.primary;
                }
                return context.colors.textSecondary;
              }),
              side: WidgetStateProperty.all(
                BorderSide(color: context.colors.surface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── GPS 지역 확인 BottomSheet (Phase 4 디자인) ──────────────────────
class _RegionConfirmSheet extends StatelessWidget {
  final DetectedRegion region;

  const _RegionConfirmSheet({required this.region});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 핸들 바
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // 제목
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '📍 홈 지역 설정',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'GPS로 현재 위치를 감지했어요',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 지역 정보 카드 (시·도 / 구·군 / 동네)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: context.colors.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _RegionRow(label: '시·도', value: region.si),
                Divider(
                  color: Colors.grey.shade800,
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                ),
                _RegionRow(label: '구·군', value: region.gu),
                Divider(
                  color: Colors.grey.shade800,
                  height: 1,
                  indent: 20,
                  endIndent: 20,
                ),
                _RegionRow(label: '동네', value: region.dong),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // CTA 버튼 — "이 지역으로 설정하기"
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
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
              child: const Text('이 지역으로 설정하기'),
            ),
          ),
          const SizedBox(height: 12),

          // 보조 버튼 — "직접 선택하기" (추후 수동 지역 선택 연결)
          GestureDetector(
            onTap: () => Navigator.pop(context, false),
            child: Text(
              '직접 선택하기',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 지역 정보 한 줄 (라벨 + 값)
class _RegionRow extends StatelessWidget {
  final String label;
  final String value;

  const _RegionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 40),
          Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 마케팅 수신 동의 토글 ────────────────────────────────────────────
// 정보통신망법 § 50 대비 — 사용자가 언제든지 동의 상태 변경 가능
// 변경 시 users/{uid}.marketingConsent + marketingConsentAt(서버 타임스탬프) 갱신
class _MarketingConsentToggle extends ConsumerStatefulWidget {
  final UserEntity user;

  const _MarketingConsentToggle({required this.user});

  @override
  ConsumerState<_MarketingConsentToggle> createState() =>
      _MarketingConsentToggleState();
}

class _MarketingConsentToggleState
    extends ConsumerState<_MarketingConsentToggle> {
  bool _saving = false;

  Future<void> _toggle(bool next) async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.id)
          .update({
        'marketingConsent': next,
        'marketingConsentAt': DateTime.now().toIso8601String(),
      });
      await ref.read(authProvider.notifier).refreshUser();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next
                ? '마케팅 정보 수신에 동의하셨습니다'
                : '마케팅 정보 수신을 거부하셨습니다',
          ),
          backgroundColor: AppTheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('변경 실패: ${e.toString().replaceFirst('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 최신 user 데이터 — refreshUser 후 갱신됨
    final latest = ref.watch(authProvider).valueOrNull ?? widget.user;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '마케팅 정보 수신',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '이벤트·혜택 알림을 받습니다',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch(
                  value: latest.marketingConsent,
                  onChanged: _toggle,
                  activeThumbColor: AppTheme.primary,
                ),
        ],
      ),
    );
  }
}

// ── 개인 최고 기록 섹션 (Phase 2 — 2026-04-28) ────────────────────────
// users/{uid}/personal_records 서브컬렉션을 읽어 5종 거리 표 형태로 표시.
// 갱신 안 된 거리는 "기록 없음" 회색.
final _personalRecordsProvider =
    FutureProvider.family<List<PersonalRecord>, String>((ref, userId) async {
  final service = PersonalRecordService();
  return service.getAll(userId);
});

class _PersonalRecordsSection extends ConsumerWidget {
  final String userId;

  const _PersonalRecordsSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_personalRecordsProvider(userId));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                '개인 최고 기록',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => ErrorView(
              error: e,
              inline: true,
              onRetry: () => ref.invalidate(_personalRecordsProvider(userId)),
            ),
            data: (records) => _buildTable(context, records),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context, List<PersonalRecord> records) {
    final byKey = {for (final r in records) r.distance.key: r};
    return Column(
      children: [
        for (final pr in PersonalRecordService.distances)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    pr.label,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    byKey[pr.key]?.formattedTime ?? '-',
                    style: TextStyle(
                      color: byKey[pr.key] != null
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
                      fontSize: 14,
                      fontWeight: byKey[pr.key] != null
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
