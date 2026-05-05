// 앱 환경 설정
// 실행 방법:
//   개발: flutter run --dart-define=FLAVOR=dev
//   프로덕션: flutter run --dart-define=FLAVOR=prod
//   프로드 빌드: flutter build apk --dart-define=FLAVOR=prod

enum AppEnvironment { dev, prod }

class AppEnv {
  // --dart-define=FLAVOR=dev|prod 로 주입, 기본값은 dev
  static const _flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  static AppEnvironment get current =>
      _flavor == 'prod' ? AppEnvironment.prod : AppEnvironment.dev;

  static bool get isDev => current == AppEnvironment.dev;
  static bool get isProd => current == AppEnvironment.prod;

  // 앱 이름 (개발 빌드에서는 "(Dev)" 표시로 구분)
  static String get appName => isDev ? 'Runtify (Dev)' : 'Runtify';

  // 환경 라벨 (로그/디버깅용)
  static String get label => _flavor.toUpperCase();
}

// 기능 플래그 (출시 단계별 토글)
class FeatureFlags {
  // 리워드 스토어 — 1차 출시에서는 숨김 (사업자 등록·통신판매업 신고 후 활성화 예정)
  // 코드/라우트는 유지, UI 진입점(BottomNav 5번째 탭, 홈 배너)만 차단
  static const bool rewardEnabled = false;
}
