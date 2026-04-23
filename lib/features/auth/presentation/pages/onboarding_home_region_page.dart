import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

// 가입 직후 홈 지역 설정 강제 온보딩 화면.
// 정책: 신규 가입자는 홈 지역을 설정하거나 명시적으로 "건너뛰기" 해야 홈에 진입.
// - 기본 경로: /onboarding/home-region
// - 재진입: auth_router_state 에서 homeRegionSi 이 null 인 한 다시 이 페이지로 리다이렉트
// - 건너뛰기: users/{id}/homeRegionSkipped = true 로 기록해 리다이렉트 루프 방지
class OnboardingHomeRegionPage extends ConsumerStatefulWidget {
  const OnboardingHomeRegionPage({super.key});

  @override
  ConsumerState<OnboardingHomeRegionPage> createState() =>
      _OnboardingHomeRegionPageState();
}

class _OnboardingHomeRegionPageState
    extends ConsumerState<OnboardingHomeRegionPage> {
  bool _isLoading = false;
  String? _errorMessage;

  // GPS 감지 → 저장 → /home 이동
  Future<void> _detectAndSave() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = ref.read(authProvider).valueOrNull;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = '로그인 상태를 확인해주세요';
      });
      return;
    }

    final detect = ref.read(detectCurrentRegionProvider);
    final (region, error) = await detect();

    if (!mounted) return;

    if (error != null || region == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = error ?? '지역을 감지할 수 없습니다';
      });
      return;
    }

    final save = ref.read(saveHomeRegionProvider);
    try {
      await save(user.id, region);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '저장 실패: ${e.toString().replaceFirst('Exception: ', '')}';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '홈 지역이 설정되었습니다: ${[region.si, region.gu, region.dong].where((s) => s.isNotEmpty).join(' ')}',
        ),
        backgroundColor: AppTheme.primary,
      ),
    );

    // 라우터 redirect 가 /home 으로 재평가하도록 이동
    context.go('/home');
  }

  // 강한 안내 다이얼로그 후 스킵 마크
  Future<void> _skip() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '정말 건너뛰시겠어요?',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: const Text(
          '홈 지역을 설정하지 않으면 내 지역 랭킹에 반영되지 않습니다.\n'
          '언제든지 프로필 > 내 지역에서 다시 설정할 수 있어요.',
          style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              '지금 설정할게요',
              style: TextStyle(color: AppTheme.primary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              '건너뛰기',
              style: TextStyle(color: Color(0xFF9E9E9E)),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    // 세션 단위 스킵 플래그 — 라우터가 리다이렉트 루프에 빠지지 않도록 표시
    markHomeRegionOnboardingSkipped(user.id);

    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // 로고·제목·설명
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.location_on,
                    size: 48,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '내 홈 지역을 알려주세요',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                '내 지역 랭킹과 크루 매칭을 위해\n'
                '홈 지역을 설정해주세요.\n'
                '여행 중에도 달린 기록은 홈 지역에 반영됩니다.',
                style: TextStyle(
                  color: Color(0xFF9E9E9E),
                  fontSize: 14,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[200], fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const Spacer(flex: 3),

              // 메인 CTA
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _detectAndSave,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.gps_fixed, size: 20),
                  label: const Text(
                    '내 위치로 지역 설정하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 건너뛰기
              TextButton(
                onPressed: _isLoading ? null : _skip,
                child: Text(
                  '건너뛰기',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 세션 스킵 마크 (라우터 리다이렉트 루프 방지) ─────────────────
// 유저가 "건너뛰기"를 명시적으로 선택한 세션에서만 true.
// 앱 재시작 시 초기화됨 → 다음 실행 때 또다시 온보딩 화면이 뜸 (정책상 의도된 동작).
final Set<String> _skippedUserIds = <String>{};

bool isHomeRegionOnboardingSkipped(String userId) =>
    _skippedUserIds.contains(userId);

void markHomeRegionOnboardingSkipped(String userId) {
  _skippedUserIds.add(userId);
}
