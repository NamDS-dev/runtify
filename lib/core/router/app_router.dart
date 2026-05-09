import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'auth_router_state.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/onboarding_home_region_page.dart';
import '../../features/auth/presentation/pages/recover_account_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/pages/social_login_page.dart';
import '../../features/crew/presentation/pages/crew_challenge_page.dart';
import '../../features/crew/presentation/pages/crew_event_page.dart';
import '../../features/crew/presentation/pages/crew_member_manage_page.dart';
import '../../features/crew/presentation/pages/crew_create_page.dart';
import '../../features/crew/presentation/pages/crew_detail_page.dart';
import '../../features/course/presentation/pages/course_detail_page.dart';
import '../../features/course/presentation/pages/course_list_page.dart';
import '../../features/legal/presentation/pages/privacy_policy_page.dart';
import '../../features/legal/presentation/pages/terms_of_service_page.dart';
import '../../features/onboarding/presentation/pages/ble_onboarding_page.dart';
import '../../features/onboarding/presentation/pages/health_connect_onboarding_page.dart';
import '../../features/crew/presentation/pages/crew_page.dart';
import '../../features/crew/domain/entities/crew_entity.dart';
import '../../features/reward/presentation/pages/ranking_page.dart';
import '../../features/reward/presentation/pages/reward_page.dart';
import '../../features/running/domain/entities/running_session_entity.dart';
import '../../features/running/presentation/pages/home_page.dart';
import '../../features/running/presentation/pages/running_detail_page.dart';
import '../../features/running/presentation/pages/running_page.dart';
import '../../features/running/presentation/pages/running_result_page.dart';
import '../../features/running/presentation/pages/running_section_page.dart';
import '../widgets/scaffold_with_bottom_nav.dart';

// 플랫폼별 페이지 생성 헬퍼
// iOS: CupertinoPage → 좌측 엣지 스와이프로 뒤로가기 제스처 자동 활성화
// 그 외(Android/Web/Desktop): MaterialPage → 기존 머티리얼 전환 유지
Page<dynamic> _platformPage({required LocalKey key, required Widget child}) {
  if (!kIsWeb && Platform.isIOS) {
    return CupertinoPage<dynamic>(key: key, child: child);
  }
  return MaterialPage<dynamic>(key: key, child: child);
}

// 앱 라우터 (go_router + ShellRoute)
// ShellRoute: 5개 메인 탭에 공통 BottomNav 적용
// ShellRoute 밖: 로그인, 러닝 트래킹, 서브 화면 (BottomNav 없음)
final appRouter = GoRouter(
  initialLocation: '/home',
  refreshListenable: authRouterStateNotifier,
  // 가입 직후 홈 지역 미설정 사용자는 /onboarding/home-region 으로 강제 이동.
  // 단, 로그인/법적 고지/온보딩 경로는 리다이렉트 제외.
  redirect: (context, state) {
    final user = authRouterStateNotifier.value;
    if (user == null) return null; // 비로그인은 기존 플로우 유지

    final loc = state.matchedLocation;

    // 회원 탈퇴 30일 유예 중 → 강제 복구 페이지로 이동 (POLICY § 4)
    // /login 만 예외 — 사용자가 "로그아웃" 선택할 수 있어야 함
    if (user.isPendingDeletion) {
      if (loc.startsWith('/login') || loc == '/recover-account') return null;
      return '/recover-account';
    }

    if (loc.startsWith('/login') ||
        loc.startsWith('/legal') ||
        loc.startsWith('/onboarding') ||
        loc == '/recover-account') {
      return null;
    }

    final needs = (user.homeRegionSi == null || user.homeRegionSi!.isEmpty);
    if (!needs) return null;
    if (isHomeRegionOnboardingSkipped(user.id)) return null;

    return '/onboarding/home-region';
  },
  routes: [
    // ── 로그인 플로우 (BottomNav 없음) ─────────────────────────────────────
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: const SocialLoginPage(),
      ),
    ),
    GoRoute(
      path: '/login/email',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: const LoginPage(),
      ),
    ),

    // ── 메인 탭 쉘 (5개 탭에 공통 BottomNav 적용) ──────────────────────────
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithBottomNav(
        location: state.matchedLocation,
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => _platformPage(
            key: state.pageKey,
            child: const HomePage(),
          ),
        ),
        GoRoute(
          // 러닝 섹션 허브 (기록/캘린더/목표 내부 탭)
          path: '/running-section',
          pageBuilder: (context, state) => _platformPage(
            key: state.pageKey,
            child: const RunningSectionPage(),
          ),
        ),
        GoRoute(
          path: '/crew',
          pageBuilder: (context, state) => _platformPage(
            key: state.pageKey,
            child: const CrewPage(),
          ),
        ),
        GoRoute(
          path: '/ranking',
          pageBuilder: (context, state) => _platformPage(
            key: state.pageKey,
            child: const RankingPage(),
          ),
        ),
        GoRoute(
          path: '/reward',
          pageBuilder: (context, state) => _platformPage(
            key: state.pageKey,
            child: const RewardPage(),
          ),
        ),
      ],
    ),

    // ── 서브 화면들 (BottomNav 없음) ─────────────────────────────────────
    GoRoute(
      // 실제 러닝 트래킹 화면 (러닝 시작 시 진입)
      path: '/running',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: const RunningPage(),
      ),
    ),
    GoRoute(
      // 러닝 완료 결과 화면
      // extra: Map<String, dynamic> {
      //   'session': RunningSessionEntity?,
      //   'needRegionConfirm': bool,
      //   'startGu': String,
      //   'endGu': String,
      // }
      path: '/running/result',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final session = extra?['session'] as RunningSessionEntity?;
        final needRegionConfirm = (extra?['needRegionConfirm'] as bool?) ?? false;
        final startGu = (extra?['startGu'] as String?) ?? '';
        final endGu = (extra?['endGu'] as String?) ?? '';
        return _platformPage(
          key: state.pageKey,
          child: RunningResultPage(
            session: session,
            needRegionConfirm: needRegionConfirm,
            startGu: startGu,
            endGu: endGu,
          ),
        );
      },
    ),
    GoRoute(
      // 러닝 기록 상세 화면 (extra: RunningSessionEntity)
      path: '/running/detail',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: RunningDetailPage(
          session: state.extra as RunningSessionEntity,
        ),
      ),
    ),
    GoRoute(
      // 크루 상세 화면 (extra: CrewEntity)
      path: '/crew/detail',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: CrewDetailPage(
          crew: state.extra as CrewEntity,
        ),
      ),
    ),
    GoRoute(
      // 크루 생성 화면
      path: '/crew/create',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: const CrewCreatePage(),
      ),
    ),
    GoRoute(
      // 크루 위클리 챌린지 화면 (BottomNav 없음, extra: CrewEntity)
      path: '/crew/challenge',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: CrewChallengePage(
          crew: state.extra as CrewEntity,
        ),
      ),
    ),
    GoRoute(
      path: '/crew/events',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: CrewEventPage(
          crew: state.extra as CrewEntity,
        ),
      ),
    ),
    GoRoute(
      path: '/crew/members',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: CrewMemberManagePage(
          crew: state.extra as CrewEntity,
        ),
      ),
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: const ProfilePage(),
      ),
    ),
    // ── 온보딩 (홈 지역 강제 설정) ──────────────────────────────────
    GoRoute(
      path: '/onboarding/home-region',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: const OnboardingHomeRegionPage(),
      ),
    ),

    // ── 회원 탈퇴 30일 유예 중 — 복구/로그아웃 선택 (POLICY § 4) ─────
    GoRoute(
      path: '/recover-account',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: const RecoverAccountPage(),
      ),
    ),

    // ── 온보딩 (Health Connect) ────────────────────────────────────
    GoRoute(
      path: '/onboarding/health',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: const HealthConnectOnboardingPage(),
      ),
    ),
    GoRoute(
      path: '/onboarding/ble',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: const BleOnboardingPage(),
      ),
    ),
    // ── 법적 고지 (이용약관/개인정보 처리방침) ─────────────────────
    GoRoute(
      path: '/legal/terms',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: const TermsOfServicePage(),
      ),
    ),
    GoRoute(
      path: '/legal/privacy',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: const PrivacyPolicyPage(),
      ),
    ),

    // ── 코스 관련 (Phase 8) ─────────────────────────────────────────
    GoRoute(
      path: '/courses',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: const CourseListPage(),
      ),
    ),
    GoRoute(
      path: '/courses/:id',
      pageBuilder: (context, state) => _platformPage(
        key: state.pageKey,
        child: CourseDetailPage(
          courseId: state.pathParameters['id']!,
        ),
      ),
    ),
  ],
);
