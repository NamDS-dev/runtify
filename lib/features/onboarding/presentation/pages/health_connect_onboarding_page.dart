// Health Connect 온보딩 — 3단계 가이드
// Step 1: Health Connect 설치 (미설치 시)
// Step 2: 삼성 헬스 동기화 안내
// Step 3: Runtify 권한 허용

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';

// 온보딩 완료 여부 확인 (홈 등 외부에서 호출)
Future<bool> isHealthOnboardingCompleted() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('health_connect_onboarding_done') ?? false;
}

class HealthConnectOnboardingPage extends StatefulWidget {
  const HealthConnectOnboardingPage({super.key});

  @override
  State<HealthConnectOnboardingPage> createState() =>
      _HealthConnectOnboardingPageState();
}

class _HealthConnectOnboardingPageState
    extends State<HealthConnectOnboardingPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = true;
  bool _healthConnectInstalled = false;
  bool _permissionsGranted = false;

  // Health Connect에서 필요한 데이터 타입
  static final List<HealthDataType> _requiredTypes = [
    HealthDataType.WORKOUT,
    HealthDataType.HEART_RATE,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.STEPS,
  ];

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 현재 상태 자동 감지
  Future<void> _checkStatus() async {
    if (kIsWeb) {
      // 웹에서는 Health Connect 미지원 → 바로 완료
      setState(() => _isLoading = false);
      return;
    }

    try {
      final health = Health();

      // 1. Health Connect 설치 여부
      _healthConnectInstalled = await health.isHealthConnectAvailable();

      // 2. 권한 이미 허용 여부
      if (_healthConnectInstalled) {
        _permissionsGranted =
            await health.hasPermissions(_requiredTypes) ?? false;
      }

      // 자동 스킵: 이미 권한 허용됨 → 온보딩 완료 처리
      if (_permissionsGranted) {
        await _markCompleted();
        if (mounted) context.go('/home');
        return;
      }

      // 설치됨 → Step 1 건너뛰고 Step 2부터
      if (_healthConnectInstalled) {
        _currentStep = 1;
        _pageController.jumpToPage(1);
      }
    } catch (e) {
      debugPrint('Health Connect 상태 확인 실패: $e');
    }

    setState(() => _isLoading = false);
  }

  // 온보딩 완료 표시 (SharedPreferences)
  Future<void> _markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('health_connect_onboarding_done', true);
  }

  // 온보딩 완료 여부 확인은 파일 상단 isHealthOnboardingCompleted() 사용

  // Step 이동
  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Health Connect Play Store 설치
  Future<void> _installHealthConnect() async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // 삼성 헬스 앱 열기
  Future<void> _openSamsungHealth() async {
    final uri = Uri.parse('samsunghealth://');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // 삼성 헬스 없으면 Play Store로
      final storeUri = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.sec.android.app.shealth',
      );
      if (await canLaunchUrl(storeUri)) {
        await launchUrl(storeUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  // Health Connect 권한 요청
  Future<void> _requestPermissions() async {
    if (kIsWeb) {
      await _markCompleted();
      if (mounted) context.go('/home');
      return;
    }

    try {
      final health = Health();
      final granted = await health.requestAuthorization(_requiredTypes);
      if (granted) {
        await _markCompleted();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '워치 연동이 완료되었습니다!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppTheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            ),
          );
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '권한 요청에 실패했습니다. 다시 시도해주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFFF3333),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      }
    }
  }

  // "나중에 하기" → 스킵 처리
  Future<void> _skipOnboarding() async {
    await _markCompleted();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 웹에서는 바로 완료 안내
    if (kIsWeb) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⌚', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              Text(
                'Health Connect는 모바일에서만\n사용할 수 있습니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 16,
                ),
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

    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(), // 스와이프 비활성화
          onPageChanged: (index) => setState(() => _currentStep = index),
          children: [
            // Step 1: Health Connect 설치
            _StepPage(
              stepNumber: 1,
              totalSteps: 3,
              currentStep: _currentStep,
              title: 'Health Connect 설치',
              description: '갤럭시 워치의 러닝 데이터를 가져오려면\nHealth Connect 앱이 필요해요',
              icon: '❤️‍🔥',
              ctaText: 'Health Connect 설치하기',
              onCtaPressed: _installHealthConnect,
              secondaryText: '이미 설치했어요 →',
              onSecondaryPressed: () => _goToStep(1),
              onSkip: _skipOnboarding,
            ),

            // Step 2: 삼성 헬스 동기화
            _StepPage(
              stepNumber: 2,
              totalSteps: 3,
              currentStep: _currentStep,
              title: '삼성 헬스 동기화',
              description: '삼성 헬스 앱에서 Health Connect\n동기화를 켜주세요',
              guideSteps: const [
                '① 삼성 헬스 앱 열기',
                '② 설정 → 연결된 서비스',
                '③ Health Connect 동기화 켜기',
              ],
              guideHint: '운동, 심박수, 수면 데이터 모두\n동기화 허용을 권장합니다',
              ctaText: '삼성 헬스 앱 열기',
              onCtaPressed: _openSamsungHealth,
              secondaryText: '설정 완료했어요 →',
              onSecondaryPressed: () => _goToStep(2),
              onSkip: _skipOnboarding,
            ),

            // Step 3: 권한 허용
            _StepPage(
              stepNumber: 3,
              totalSteps: 3,
              currentStep: _currentStep,
              title: 'Runtify 권한 허용',
              description: 'Health Connect에서 Runtify가\n데이터를 읽을 수 있도록 허용해주세요',
              permissions: const [
                '🏃 운동 기록 (러닝 거리, 시간, 페이스)',
                '❤️ 심박수 (평균/최대 심박)',
                '🔥 칼로리 소모량',
                '👟 걸음 수',
              ],
              privacyNote: '🔒 데이터는 기기에만 저장되며 외부로 전송되지 않습니다',
              ctaText: '권한 허용하기',
              onCtaPressed: _requestPermissions,
              onSkip: _skipOnboarding,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 개별 스텝 페이지 위젯 ──────────────────────────────────────────────
class _StepPage extends StatelessWidget {
  final int stepNumber;
  final int totalSteps;
  final int currentStep;
  final String title;
  final String description;
  final String? icon; // Step 1용 (큰 이모지)
  final List<String>? guideSteps; // Step 2용 (가이드 목록)
  final String? guideHint; // Step 2용 (힌트)
  final List<String>? permissions; // Step 3용 (권한 목록)
  final String? privacyNote; // Step 3용 (개인정보 안내)
  final String ctaText;
  final VoidCallback onCtaPressed;
  final String? secondaryText;
  final VoidCallback? onSecondaryPressed;
  final VoidCallback onSkip;

  const _StepPage({
    required this.stepNumber,
    required this.totalSteps,
    required this.currentStep,
    required this.title,
    required this.description,
    this.icon,
    this.guideSteps,
    this.guideHint,
    this.permissions,
    this.privacyNote,
    required this.ctaText,
    required this.onCtaPressed,
    this.secondaryText,
    this.onSecondaryPressed,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),

          // Step 표시
          Text(
            'Step $stepNumber / $totalSteps',
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // 제목
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // 설명
          Text(
            description,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 32),

          // 콘텐츠 영역 (Step별로 다름)
          Expanded(child: _buildContent(context)),

          // 하단 영역 (진행 dot + 버튼들)
          _buildDots(),
          const SizedBox(height: 16),

          // CTA 버튼
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onCtaPressed,
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
              child: Text(ctaText),
            ),
          ),

          // 보조 버튼 (있을 때만)
          if (secondaryText != null) ...[
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: onSecondaryPressed,
                child: Text(
                  secondaryText!,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],

          // 나중에 하기
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: onSkip,
              child: Text(
                '나중에 하기',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Step별 콘텐츠
  Widget _buildContent(BuildContext context) {
    // Step 1: 큰 아이콘
    if (icon != null) {
      return Center(
        child: Container(
          width: 270,
          height: 270,
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(icon!, style: const TextStyle(fontSize: 80)),
          ),
        ),
      );
    }

    // Step 2: 가이드 목록
    if (guideSteps != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ...guideSteps!.map((step) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    step,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )),
            if (guideHint != null) ...[
              const SizedBox(height: 8),
              Text(
                guideHint!,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Step 3: 권한 목록
    if (permissions != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '허용할 데이터',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...permissions!.map((perm) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    perm,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                )),
            if (privacyNote != null) ...[
              const SizedBox(height: 12),
              Text(
                privacyNote!,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // 진행 dot 표시
  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final isActive = i == currentStep;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 10 : 8,
          height: isActive ? 10 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppTheme.primary : Colors.grey.shade700,
          ),
        );
      }),
    );
  }
}
