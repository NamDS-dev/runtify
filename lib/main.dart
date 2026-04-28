import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'firebase_options.dart';
import 'firebase_options_dev.dart';

Future<void> main() async {
  // runZonedGuarded 로 비동기 에러도 Crashlytics 로 라우팅 (네이티브 설정 후 활성)
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 환경별 Firebase 프로젝트 선택
    // 개발: flutter run --dart-define=FLAVOR=dev  (기본값)
    // 프로덕션: flutter run --dart-define=FLAVOR=prod
    final firebaseOptions = AppEnv.isDev
        ? DefaultFirebaseOptionsDev.currentPlatform // runtify-dev 프로젝트
        : DefaultFirebaseOptions.currentPlatform; // runtify (prod) 프로젝트

    await Firebase.initializeApp(options: firebaseOptions);

    // Crashlytics 글로벌 에러 핸들러 등록
    // - Flutter framework 에러 (위젯 build 실패 등)
    // - Dart 비동기/uncaught 에러 (PlatformDispatcher)
    // 네이티브 google-services 미설치 환경에서는 try/catch 로 silent 처리
    try {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (_) {
      // Crashlytics 미초기화 환경 — debugPrint 만 사용
    }

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
  }, (error, stack) {
    // runZonedGuarded 가 잡은 비동기 에러 — Crashlytics 로 전송
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {
      // Crashlytics 미초기화 — fallthrough (재throw 안 함, 앱 흐름 유지)
    }
  });
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
      // 데스크톱/웹에서만 모바일 크기로 중앙 정렬 — 실제 iOS/Android 기기에서는 네이티브 너비 사용
      builder: (context, child) {
        final isDesktopOrWeb = kIsWeb ||
            (!Platform.isIOS && !Platform.isAndroid);
        if (!isDesktopOrWeb) {
          return child ?? const SizedBox.shrink();
        }
        return ColoredBox(
          color: Colors.black,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
