import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'firebase_options.dart';
import 'firebase_options_dev.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경별 Firebase 프로젝트 선택
  // 개발: flutter run --dart-define=FLAVOR=dev  (기본값)
  // 프로덕션: flutter run --dart-define=FLAVOR=prod
  final firebaseOptions = AppEnv.isDev
      ? DefaultFirebaseOptionsDev.currentPlatform  // runtify-dev 프로젝트
      : DefaultFirebaseOptions.currentPlatform;    // runtify (prod) 프로젝트

  await Firebase.initializeApp(options: firebaseOptions);

  // 앱 시작 전에 저장된 테마 설정 로드
  final savedTheme = await loadSavedTheme();

  // 개발 환경에서는 콘솔에 환경 표시
  assert(() {
    debugPrint('🚀 Runtify 실행 환경: ${AppEnv.label}');
    return true;
  }());

  runApp(
    ProviderScope(
      overrides: [
        // 저장된 테마로 초기값 주입
        themeProvider.overrideWith((ref) => ThemeNotifier(savedTheme)),
      ],
      child: const RuntifyApp(),
    ),
  );
}

// ConsumerWidget으로 변경하여 themeProvider 감시
class RuntifyApp extends ConsumerWidget {
  const RuntifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: AppEnv.appName, // 개발: 'Runtify (Dev)', 프로덕션: 'Runtify'
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: AppEnv.isDev, // 개발 빌드에서만 DEBUG 배너 표시
      // 모바일 앱 레이아웃 제한 — 데스크톱/웹에서도 모바일 크기로 중앙 정렬
      builder: (context, child) {
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
