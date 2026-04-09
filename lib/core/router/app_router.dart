import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/pages/social_login_page.dart';
import '../../features/crew/presentation/pages/crew_challenge_page.dart';
import '../../features/crew/presentation/pages/crew_create_page.dart';
import '../../features/crew/presentation/pages/crew_detail_page.dart';
import '../../features/course/presentation/pages/course_detail_page.dart';
import '../../features/course/presentation/pages/course_list_page.dart';
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

// 앱 라우터 (go_router + ShellRoute)
// ShellRoute: 5개 메인 탭에 공통 BottomNav 적용
// ShellRoute 밖: 로그인, 러닝 트래킹, 서브 화면 (BottomNav 없음)
final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    // ── 로그인 플로우 (BottomNav 없음) ─────────────────────────────────────
    GoRoute(
      path: '/login',
      builder: (context, state) => const SocialLoginPage(),
    ),
    GoRoute(
      path: '/login/email',
      builder: (context, state) => const LoginPage(),
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
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          // 러닝 섹션 허브 (기록/캘린더/목표 내부 탭)
          path: '/running-section',
          builder: (context, state) => const RunningSectionPage(),
        ),
        GoRoute(
          path: '/crew',
          builder: (context, state) => const CrewPage(),
        ),
        GoRoute(
          path: '/ranking',
          builder: (context, state) => const RankingPage(),
        ),
        GoRoute(
          path: '/reward',
          builder: (context, state) => const RewardPage(),
        ),
      ],
    ),

    // ── 서브 화면들 (BottomNav 없음) ─────────────────────────────────────
    GoRoute(
      // 실제 러닝 트래킹 화면 (러닝 시작 시 진입)
      path: '/running',
      builder: (context, state) => const RunningPage(),
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
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final session = extra?['session'] as RunningSessionEntity?;
        final needRegionConfirm = (extra?['needRegionConfirm'] as bool?) ?? false;
        final startGu = (extra?['startGu'] as String?) ?? '';
        final endGu = (extra?['endGu'] as String?) ?? '';
        return RunningResultPage(
          session: session,
          needRegionConfirm: needRegionConfirm,
          startGu: startGu,
          endGu: endGu,
        );
      },
    ),
    GoRoute(
      // 러닝 기록 상세 화면 (extra: RunningSessionEntity)
      path: '/running/detail',
      builder: (context, state) => RunningDetailPage(
        session: state.extra as RunningSessionEntity,
      ),
    ),
    GoRoute(
      // 크루 상세 화면 (extra: CrewEntity)
      path: '/crew/detail',
      builder: (context, state) => CrewDetailPage(
        crew: state.extra as CrewEntity,
      ),
    ),
    GoRoute(
      // 크루 생성 화면
      path: '/crew/create',
      builder: (context, state) => const CrewCreatePage(),
    ),
    GoRoute(
      // 크루 위클리 챌린지 화면 (BottomNav 없음, extra: CrewEntity)
      path: '/crew/challenge',
      builder: (context, state) => CrewChallengePage(
        crew: state.extra as CrewEntity,
      ),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfilePage(),
    ),
    // ── 온보딩 (Health Connect) ────────────────────────────────────
    GoRoute(
      path: '/onboarding/health',
      builder: (context, state) => const HealthConnectOnboardingPage(),
    ),
    GoRoute(
      path: '/onboarding/ble',
      builder: (context, state) => const BleOnboardingPage(),
    ),
    // ── 코스 관련 (Phase 8) ─────────────────────────────────────────
    GoRoute(
      path: '/courses',
      builder: (context, state) => const CourseListPage(),
    ),
    GoRoute(
      path: '/courses/:id',
      builder: (context, state) => CourseDetailPage(
        courseId: state.pathParameters['id']!,
      ),
    ),
  ],
);
