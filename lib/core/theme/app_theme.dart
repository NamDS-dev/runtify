import 'package:flutter/material.dart';
import 'app_colors.dart';

export 'app_colors.dart'; // app_theme.dart import 시 context.colors도 자동 포함

// Runtify 앱 테마 - Sunset Fire 팔레트 (라이트/다크 모두 지원)
class AppTheme {
  // 라이트/다크 공통 포인트 색상 (Sunset Fire)
  static const Color primary = Color(0xFFFF4D00);   // 번 오렌지
  static const Color secondary = Color(0xFFFF9A3C); // 선셋 오렌지
  static const Color accent = Color(0xFFFFE566);    // 골든 옐로우

  // ── 라이트 테마 ─────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.light.background,
    extensions: const [AppColors.light],
    colorScheme: ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: AppColors.light.surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.light.background,
      foregroundColor: AppColors.light.textPrimary,
      elevation: 0,
      shadowColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: AppColors.light.cardColor,
      elevation: 1,
      shadowColor: Colors.black12,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: primary),
        foregroundColor: primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.light.surface,
      selectedItemColor: primary,
      unselectedItemColor: AppColors.light.textSecondary,
      elevation: 0,
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
          color: AppColors.light.textPrimary, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(
          color: AppColors.light.textPrimary, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: AppColors.light.textPrimary),
      bodyMedium: TextStyle(color: AppColors.light.textSecondary),
    ),
  );

  // ── 다크 테마 ─────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.dark.background,
    extensions: const [AppColors.dark],
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: AppColors.dark.surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.dark.background,
      foregroundColor: AppColors.dark.textPrimary,
      elevation: 0,
      shadowColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: AppColors.dark.cardColor,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: primary),
        foregroundColor: primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.dark.surface,
      selectedItemColor: primary,
      unselectedItemColor: AppColors.dark.textSecondary,
      elevation: 0,
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
          color: AppColors.dark.textPrimary, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(
          color: AppColors.dark.textPrimary, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: AppColors.dark.textPrimary),
      bodyMedium: TextStyle(color: AppColors.dark.textSecondary),
    ),
  );
}
